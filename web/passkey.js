// Local vault encryption using WebAuthn PRF. No server login or raw-key storage.
(() => {
  let active = null;
  const encode = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes)));
  const decode = text => Uint8Array.from(atob(text), c => c.charCodeAt(0));
  const random = () => crypto.getRandomValues(new Uint8Array(32));
  const b64url = bytes => encode(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  const fail = message => { throw new Error(message); };
  const supported = () => window.isSecureContext && !!window.PublicKeyCredential &&
    !!navigator.credentials?.create && !!navigator.credentials?.get;
  const assertSupported = () => {
    if (!supported()) fail('当前浏览器无法使用通行密钥，请使用 HTTPS 或 localhost，并启用密码管理器。');
    if (window.top !== window.self) fail('请在独立浏览器页面中启用通行密钥。');
  };
  const prfInput = salt => {
    const prefix = new TextEncoder().encode('WindBlog vault wrapping v1\0');
    const value = decode(salt);
    if (value.length !== 32) fail('通行密钥配置已损坏，请使用主密码。');
    const input = new Uint8Array(prefix.length + value.length);
    input.set(prefix); input.set(value, prefix.length);
    return input;
  };
  const evaluate = async (record, signal) => {
    if (record.origin !== location.origin || record.rpId !== location.hostname)
      fail('通行密钥绑定的站点已改变，请在原站点使用或用主密码重新启用。');
    const challenge = random();
    const credential = await navigator.credentials.get({
      signal,
      publicKey: {
        challenge, rpId: record.rpId, timeout: 60000,
        allowCredentials: [{type: 'public-key', id: decode(record.credentialId)}],
        userVerification: 'required',
        extensions: {prf: {eval: {first: prfInput(record.salt)}}},
      },
    });
    if (!credential || encode(credential.rawId) !== record.credentialId)
      fail('未完成通行密钥认证，请使用主密码。');
    const client = JSON.parse(new TextDecoder().decode(credential.response.clientDataJSON));
    const data = new Uint8Array(credential.response.authenticatorData);
    if (client.type !== 'webauthn.get' || client.origin !== record.origin ||
        client.challenge !== b64url(challenge) || client.crossOrigin === true ||
        data.length < 37 || (data[32] & 5) !== 5)
      fail('通行密钥身份验证未通过，请使用主密码。');
    const rpHash = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(record.rpId)));
    if (!rpHash.every((byte, index) => byte === data[index]))
      fail('通行密钥站点验证未通过，请使用主密码。');
    const output = credential.getClientExtensionResults()?.prf?.results?.first;
    if (!output || output.byteLength !== 32)
      fail('所选密码管理器或通行密钥不支持 PRF，无法解密实例库。请使用主密码，或选择支持 PRF 的认证器。');
    return {secret: encode(output)};
  };
  const operation = async callback => {
    if (active) return JSON.stringify({error: '已有通行密钥认证正在进行。'});
    const controller = new AbortController();
    active = controller;
    const timer = setTimeout(() => controller.abort(), 120000);
    try {
      assertSupported();
      const result = await callback(controller.signal);
      if (controller.signal.aborted) fail('通行密钥认证已取消或超时，请重试或使用主密码。');
      return JSON.stringify(result);
    } catch (error) {
      const canceled = ['AbortError', 'NotAllowedError'].includes(error.name);
      return JSON.stringify({error: canceled ? '通行密钥认证已取消或超时，请重试或使用主密码。' :
        error.name === 'SecurityError' ? '浏览器拒绝通行密钥请求，请检查 HTTPS 和站点域名。' : error.message});
    } finally {
      clearTimeout(timer);
      if (active === controller) active = null;
    }
  };
  window.windblogPasskeyAvailable = supported;
  window.windblogPasskeyCancel = () => active?.abort();
  window.windblogPasskeyEvaluate = record => operation(signal => evaluate(JSON.parse(record), signal));
  window.windblogPasskeyRegister = () => operation(async signal => {
    const salt = encode(random());
    const credential = await navigator.credentials.create({signal, publicKey: {
      rp: {id: location.hostname, name: 'WindBlog Admin'},
      user: {id: random(), name: 'WindBlog local vault', displayName: 'WindBlog 实例库'},
      challenge: random(), timeout: 60000, attestation: 'none',
      pubKeyCredParams: [{type: 'public-key', alg: -7}, {type: 'public-key', alg: -257}],
      authenticatorSelection: {residentKey: 'required', userVerification: 'required'},
      extensions: {prf: {}},
    }});
    if (!credential) fail('未创建通行密钥，请重试。');
    if (credential.getClientExtensionResults()?.prf?.enabled !== true)
      fail('所选密码管理器或通行密钥不支持 PRF，尚未启用实例库解锁。请继续使用主密码；已创建的通行密钥可在密码管理器中删除。');
    const record = {credentialId: encode(credential.rawId), salt,
      rpId: location.hostname, origin: location.origin};
    // Always test an assertion before persisting an envelope, including when
    // registration reports PRF support but cannot evaluate it itself.
    return {...record, ...await evaluate(record, signal)};
  });
})();
