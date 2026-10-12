# 实例库系统认证解锁

先用主密码解锁，在实例管理中点击“启用系统解锁”，完成系统认证。下次启动可点击“使用系统认证解锁”。关闭系统解锁会删除保存的解密密钥；主密码和实例数据不变。

支持 Android 7+ 的生物识别或设备凭据、iOS 15+ / macOS 12+ 的 LocalAuthentication、Windows 10 1607+ 的 Windows Hello。Linux 使用 fprintd，需启动该服务并为当前用户录入指纹；没有指纹时使用主密码。Web 支持主密码和具备 PRF 能力的通行密钥。认证不可用、取消或失败时均可使用主密码。

启用后，主密码派生的 AES 密钥额外保存到 flutter_secure_storage，不保存主密码。应用只有在系统认证成功后读取密钥并解密实例库。这是应用认证门禁加系统安全存储，并非所有平台均提供每次读取密钥的硬件认证绑定。锁定时仍清除内存中的密钥和凭据。

设备验收需覆盖启用、重启后解锁、取消与失败、关闭认证、未配置认证方式及主密码回退。原生弹窗需要对应平台实测。

Linux 通过 Dart 异步子进程调用 fprintd-list / fprintd-verify，避免插件的同步 system() 阻塞 GTK 界面线程。可取消认证；认证等待最多 30 秒，能力检测最多 5 秒。只有退出成功且输出明确包含 verify-match (done) 才能解锁。

## 浏览器通行密钥（试验）

在 HTTPS 或 localhost 上打开 Flutter Web，先用主密码解锁，在“多实例管理 / 保存登录方式”中点击“启用通行密钥解锁”。浏览器会请求创建 WindBlog Admin 通行密钥，可选择 Bitwarden 等密码管理器；随后需要再完成一次认证以验证 PRF 输出。支持 PRF 才保存配置，否则显示具体原因，保持主密码可用。Cloudflare 通行密钥认证成功只能证明 WebAuthn 认证支持，不能代替本应用的 PRF 检测。

用 PRF 输出通过 HKDF 派生包裹密钥，用 AES-GCM 加密主密码派生的实例库密钥；保存的配置只有 credential ID、随机 PRF salt、站点 origin / RP ID 和带认证标签的密文，不保存主密码、PRF 输出或明文实例库密钥。绑定凭据和站点元数据也经过 AES-GCM 验证。每次解锁重新请求通行密钥，要求 userVerification，并检查 challenge、origin、RP ID hash 和 UV / UP 标志；解密成功才加载实例。此流程用于本地解密，不签发服务端登录凭据。

通行密钥只绑定当前站点。更换域名或端口后，请用主密码重新启用；清空浏览器数据后，本地实例库与解锁配置不会自动从 Bitwarden 恢复。关闭此功能只删除本地配置，密码管理器里的凭据需自行管理。无 PRF 的通行密钥可能已创建，但不会启用解锁，可在密码管理器中自行删除。

本地测试入口：http://localhost:8090/ 。需要在自己的 Bitwarden 中验证注册、PRF 支持和重启后解锁。测试命令：`flutter test`、`node --test test/web/passkey_test.cjs`、`flutter build web`。现有依赖不支持 WebAssembly，使用默认 JavaScript Web 构建。
