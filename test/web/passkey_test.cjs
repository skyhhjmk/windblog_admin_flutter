const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const {webcrypto} = require('node:crypto');
const source = fs.readFileSync('web/passkey.js', 'utf8');
const encoded = value => Buffer.from(value).toString('base64');
const rawId = Uint8Array.of(10, 20, 30);
const secret = new Uint8Array(32).fill(42);

function browser(options = {}) {
  const location = {origin: 'http://localhost:8090', hostname: 'localhost'};
  const calls = [];
  const window = {isSecureContext: options.secure !== false, PublicKeyCredential: class {}};
  window.top = window.self = window;
  const navigator = {credentials: {
    create: async request => {
      calls.push(['create', request]);
      return {rawId, getClientExtensionResults: () => ({prf: {enabled: options.prf !== false}})};
    },
    get: async request => {
      calls.push(['get', request]);
      if (options.wait) return new Promise((resolve, reject) => {
        request.signal.addEventListener('abort', () => reject(Object.assign(new Error('cancel'), {name: 'AbortError'})));
      });
      const data = new Uint8Array(37);
      data.set(new Uint8Array(await webcrypto.subtle.digest('SHA-256', new TextEncoder().encode('localhost'))));
      data[32] = options.uv === false ? 1 : 5;
      if (options.rpMismatch) data[0] ^= 1;
      const client = {type: 'webauthn.get', origin: location.origin,
        challenge: options.challengeMismatch ? 'wrong' : Buffer.from(request.publicKey.challenge).toString('base64url')};
      return {rawId: options.idMismatch ? Uint8Array.of(99) : rawId,
        response: {authenticatorData: data, clientDataJSON: new TextEncoder().encode(JSON.stringify(client))},
        getClientExtensionResults: () => options.missingOutput ? {} : ({prf: {results: {first: secret.buffer}}})};
    },
  }};
  vm.runInNewContext(source, {window, navigator, location, crypto: webcrypto,
    Uint8Array, TextEncoder, TextDecoder, AbortController, setTimeout, clearTimeout,
    btoa: s => Buffer.from(s, 'binary').toString('base64'), atob: s => Buffer.from(s, 'base64').toString('binary')});
  return {window, calls};
}
const record = {credentialId: encoded(rawId), salt: encoded(new Uint8Array(32)),
  origin: 'http://localhost:8090', rpId: 'localhost'};

test('registration verifies PRF assertion before reporting success', async () => {
  const {window, calls} = browser();
  const result = JSON.parse(await window.windblogPasskeyRegister());
  assert.equal(result.secret, encoded(secret));
  assert.equal(result.credentialId, record.credentialId);
  assert.deepEqual(calls.map(call => call[0]), ['create', 'get']);
  assert.equal(calls[1][1].publicKey.userVerification, 'required');
  assert.equal(calls[1][1].publicKey.allowCredentials[0].type, 'public-key');
});
test('unsupported PRF never reports usable registration', async () => {
  const {window, calls} = browser({prf: false});
  const result = JSON.parse(await window.windblogPasskeyRegister());
  assert.match(result.error, /不支持 PRF/);
  assert.equal(calls.length, 1);
  assert.equal(result.secret, undefined);
});
test('plain WebAuthn success without PRF cannot unlock', async () => {
  const {window} = browser({missingOutput: true});
  assert.match(JSON.parse(await window.windblogPasskeyEvaluate(JSON.stringify(record))).error, /不支持 PRF/);
});
for (const option of ['uv', 'rpMismatch', 'challengeMismatch', 'idMismatch']) {
  test(`${option} validation rejects untrusted assertion`, async () => {
    const {window} = browser({[option]: option === 'uv' ? false : true});
    const result = JSON.parse(await window.windblogPasskeyEvaluate(JSON.stringify(record)));
    assert.ok(result.error);
    assert.equal(result.secret, undefined);
  });
}
test('origin change is rejected before touching authenticator', async () => {
  const {window, calls} = browser();
  assert.ok(JSON.parse(await window.windblogPasskeyEvaluate(JSON.stringify({...record, origin: 'https://other.test'}))).error);
  assert.equal(calls.length, 0);
});
test('insecure browser is unavailable and fails closed', async () => {
  const {window} = browser({secure: false});
  assert.equal(window.windblogPasskeyAvailable(), false);
  assert.ok(JSON.parse(await window.windblogPasskeyRegister()).error);
});
test('cancel aborts pending request; overlapping requests are rejected', async () => {
  const {window} = browser({wait: true});
  const pending = window.windblogPasskeyEvaluate(JSON.stringify(record));
  const concurrent = JSON.parse(await window.windblogPasskeyEvaluate(JSON.stringify(record)));
  assert.match(concurrent.error, /正在进行/);
  window.windblogPasskeyCancel();
  assert.match(JSON.parse(await pending).error, /取消或超时/);
});
