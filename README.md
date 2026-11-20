# LANDeck

本地优先的局域网 Web 服务启动器。当前版本以设备为中心管理服务：

- 先添加设备（名称 + 地址），设备下的服务只需填端口，URL 自动生成
- 设备地址修改后，所有关联服务的 URL 自动更新；自定义 URL 不受影响
- 设备详情页提供「＋ 添加服务」快捷表单，默认 HTTP、端口即核心输入
- 端口自动建议名称（如 8096 → Jellyfin），名称始终可修改
- 旧版完整 URL 数据自动迁移：能匹配设备的转为设备关联，否则保留为自定义 URL

- 首次安装零服务、零收藏、零设备，空状态引导添加或扫描
- 手动添加服务，URL 支持 IP / 域名 / 端口 / HTTP / HTTPS / 路径 / Query
- Sembast 本机数据库持久化，重启 App 后数据仍在
- 真实局域网扫描：mDNS、SSDP、常见 Web 端口 TCP 探测、HTTP/HTTPS 页面验证
- 扫描结果只是候选，必须由用户确认后才会写入数据库
- 设备 CRUD；删除设备只解绑服务，不级联删除
- 真实 Android 系统 WebView，加载数据库中的 URL；Cookie 由系统 WebView 持久化
- HTTP Authentication（Basic 及系统 WebView 支持的方案）：应用内凭据弹窗、失败重试、取消不循环、可选 Keystore 加密记住
- 深色、手机优先的原有视觉风格

## 技术栈

- Flutter 3.50.0 / Dart 3.14.0
- Material 3（`material_ui`）
- `webview_flutter` 4.14.1
- `flutter_secure_storage` 11.2.0（Android Keystore + AES-GCM）
- `sembast` 3.10.1 + `sembast_web` 2.4.7
- `network_info_plus` / `multicast_dns` / `permission_handler`
- Android compileSdk 37、targetSdk 36、minSdk 24

## 运行

```bash
export PATH=/home/cyu/development/flutter/bin:$PATH
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
cd /home/cyu/Projects/LANDeck

flutter pub get
flutter analyze
flutter test
flutter run
```

Android 真机/模拟器需要允许「附近的设备」权限，才能读取 Wi-Fi 网段并扫描。App 会在扫描前说明用途；拒绝后会显示明确的权限提示和「系统设置 / 重试」入口。

### 构建 APK

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$JAVA_HOME/bin:/home/cyu/development/flutter/bin:$PATH

flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

产物：

- `dist/LANDeck-0.4.0.apk`（约 53.8 MB，含 arm64-v8a / armeabi-v7a / x86_64）
- 构建产物：`build/app/outputs/flutter-apk/app-release.apk`
- 包名 `com.example.landeck`，版本 `0.4.0+4`
- SHA-256：`4a4368bca6c94242f6735f5edb740d83500123b95405bd976c68c42fed9c65b2`
- 当前使用 Flutter 默认 debug 签名，可直接安装测试，不适合直接上架

> `permission_handler_android 13.0.2` 要求编译 SDK ≥ 37，因此 `compileSdk = 37`；`targetSdk` 保持 36。target 36 下局域网访问由 INTERNET 隐式允许，不声明/请求 `ACCESS_LOCAL_NETWORK`。

## 项目结构

```text
lib/
├── main.dart                         # 启动、打开数据库、加载仓库
├── app.dart                          # MaterialApp / AppScope / 路由
├── core/
│   ├── app_scope.dart                # 仓库的 InheritedNotifier
│   ├── theme/                        # 色板、M3 暗色主题、间距
│   └── utils/
│       ├── url_utils.dart            # URL 规范化、去重、CIDR 辅助
│       ├── html_utils.dart           # <title> 提取
│       ├── network_utils.dart        # 掩码/前缀/主机范围
│       └── feedback.dart             # SnackBar
├── models/
│   ├── service.dart                  # Service（可空 lastStatus）
│   ├── http_credential.dart          # HTTP 认证凭据（service+host+realm）
│   ├── device.dart                   # Device / DeviceType
│   ├── device_category.dart          # 服务分类
│   └── scan_candidate.dart           # 扫描候选、网络信息、进度
├── data/
│   ├── database/
│   │   ├── app_database.dart         # Sembast 数据库、services/devices store
│   │   ├── database_migration.dart   # v1 完整 URL → v2 设备关联迁移
│   │   ├── database_platform_io.dart
│   │   └── database_platform_web.dart
│   └── device_categories.dart
├── repositories/
│   └── service_repository.dart       # LanDeckRepository（ChangeNotifier）
├── services/
│   ├── network_inspector.dart        # Wi-Fi IP / 掩码 / CIDR
│   ├── lan_scanner.dart              # mDNS + SSDP + TCP + HTTP 验证
│   └── multicast_lock.dart           # Android MulticastLock 通道
├── pages/
│   ├── main_shell.dart               # 底部导航 + IndexedStack
│   ├── home/                         # 首页与收藏/分类/全部服务组件
│   ├── category/                     # 分类筛选
│   ├── discover/                     # 网络信息 + 真实扫描
│   ├── services/service_editor_page.dart
│   ├── devices/                      # 设备列表/详情/编辑
│   ├── webview/                      # 沉浸 WebView、工具栏、服务切换
│   └── settings/
└── widgets/                          # 服务行、图标、状态点、底部导航
```

数据库 store：

- `services`：id、name、deviceId、protocol、port、path、customUrl、category、icon、isFavorite、sortOrder、healthCheckEnabled、lastStatus、lastCheckedAt、createdAt、updatedAt
- `devices`：id、name、deviceType、primaryAddress、icon、notes、sortOrder、createdAt、updatedAt
- `meta/schema`：数据库结构版本（当前 v2）

`Service` 不保存设备 IP。有关联设备且无 `customUrl` 时，URL 由
`device.primaryAddress + protocol + port + path` 动态生成；`customUrl` 存在时优先使用。
`lastStatus` 默认为空，显示「未检测」；只有在真实扫描确认或 WebView 真正加载成功/失败后才写入在线/离线，不再伪造状态。

### 设备中心化 URL 规则

```text
Device.primaryAddress = 192.168.1.10
Service.protocol = http, port = 8096, path = /web
→ http://192.168.1.10:8096/web
```

- 修改设备地址后，所有关联服务立即使用新地址，无需逐个编辑。
- 自定义 URL 服务（反向代理、独立域名、复杂参数）保持原样。
- 删除设备不会删除服务：服务会冻结当前 URL，转为「未分配设备」。
- 扫描结果按 IP 匹配已有设备，并预填端口、协议、路径和名称。

## 扫描实现

1. **网络信息**：`network_info_plus` 读取 Wi-Fi IPv4 与子网掩码；失败时用 `NetworkInterface` 找本机 IPv4。允许 `/23`–`/30`，最多 512 台主机；更大网段明确拒绝，避免压垮网络。
2. **mDNS**：查询 `_http._tcp`、`_https._tcp`、`_workstation._tcp`、`_device-info._tcp`、`_home-assistant._tcp`、`_googlecast._tcp`，通过 SRV/A 记录得到主机与端口；Android 端用 `MulticastLock`。
3. **SSDP**：向 `239.255.255.250:1900` 发 M-SEARCH，只接受本网段内的响应；没有确认 Web UI 的设备不会被直接当成服务。
4. **TCP 探测**：固定常见端口列表
   `80, 443, 8000, 8080, 8443, 3000, 5000, 5001, 9090, 9443, 8096, 8920, 9000, 9091, 8989, 7878`，
   并发 64、单端口 350 ms 超时，不扫 1–65535，不跨网段。
5. **HTTP/HTTPS 验证**：对开放端口发 GET，接受局域网自签证书，跟随重定向，读取最多 64 KB，提取状态码、Server、`<title>`。任何 HTTP 响应（包括 401/403/404）都算「已确认 Web 服务」；只有 TCP 开放但没有 HTTP 响应则标为「候选」。
6. **结果**：按 host:port 去重并合并来源；显示 IP、hostname、端口、HTTP/HTTPS、标题、来源、检测状态。可取消，取消后不保留半截结果。所有结果必须用户确认后才会写入数据库，重复 URL 会提示「该地址已经添加过了」。

## HTTP 身份验证

- 使用系统 WebView 的 `onHttpAuthRequest` / `HttpAuthHandler.proceed`，不重建 WebView、不重新打开页面。
- 服务地址（host）必须与当前服务 URL 的 host 完全一致，否则取消请求并提示；不会把凭据发给第三方域名。
- 凭据按 `serviceId + host + realm` 绑定；默认不记住。勾选「记住登录信息」后使用 Android Keystore 加密保存，可在「编辑服务 → 已保存的登录信息」删除。
- 密码错误时重新弹出对话框并预填用户名、提示“认证失败，请检查用户名和密码”；同一 scope 只自动重试一次，避免死循环。
- 点「取消」只取消本次 challenge，不会自动反复弹出；刷新或重新进入服务可重新认证。
- 普通 HTML 表单登录页、无 `WWW-Authenticate` 的 401 响应不会触发该弹窗。
- 不在 URL 中写入凭据；不打印用户名/密码日志。

## 验证结果

- `flutter analyze`：No issues found
- `flutter test`：26 tests passed
- `flutter build apk --release`：成功，53.8 MB（0.4.0+4）
- Android 模拟器（Android 36 x86_64，1080×2400）实测：
  - 首次安装 0 服务、0 收藏、0 设备，空状态正常
  - 手动添加 → 首页计数/分类/收藏更新 → 强制停止再启动仍存在
  - 真实 WebView 加载本机 HTTP 测试页，内部跳转、返回、工具栏、服务切换正常
  - 真实扫描当前 Wi-Fi `10.0.2.15/24`，找到 5 个确认服务（测试宿主机 `10.0.2.2` 上的多个 Web 服务）
  - 扫描结果自动匹配已有设备，添加表单无需重新输入 IP
  - 设备快捷添加只输入端口 8096，自动生成名称 Jellyfin 和 URL `http://10.0.2.2:8096`
  - 设备地址改为 `192.168.1.2` 后，关联 Jellyfin 的 URL 自动变为 `http://192.168.1.2:8096` 并可真实打开
  - v1 数据库升级：2 个旧完整 URL 服务全部保留，未丢失
  - 删除设备后服务保留；重复 URL 拦截正常
  - 拒绝「附近设备」权限后显示权限提示与系统设置入口
  - HTTP Basic Auth：真实服务器（`10.0.2.2:9080`，realm `Padavan`）弹出应用内认证框
  - 错误密码：重新弹窗并提示，页面不重建
  - 正确密码：加载受保护页面；勾选记住后强制停止再启动可自动登录
  - 不勾选记住：重启后重新要求认证；删除已保存凭据后也会重新要求认证
  - 取消：停留在 401 页面，等待 10 秒无自动重复弹窗
  - 普通 HTML 登录页、无 WWW-Authenticate 的 401 API 均不触发认证弹窗

## 截图

目录：`screenshots/android/`

### 设备中心化（当前）

| 文件 | 内容 |
| --- | --- |
| `p1-01-migrated-home.png` | v1 → v2 升级后，旧服务全部保留 |
| `p1-02-devices-empty.png` | 设备空状态 |
| `p1-03-device-form.png` | 新建设备：名称 + 地址 |
| `p1-04-device-detail.png` | 设备详情与地址 |
| `p1-05-quick-add-form.png` | 只填端口 8096，自动建议 Jellyfin 并预览 URL |
| `p1-06-device-with-quick-service.png` | 设备下生成 Jellyfin 服务 |
| `p1-07-quick-service-webview.png` | 快捷添加的服务真实打开 |
| `p1-09-device-address-updated.png` | 修改设备地址后关联服务 URL 自动更新 |
| `p1-10-webview-after-address-change.png` | 新地址下服务仍可打开 |
| `p1-11-discover.png` | 当前网络与扫描范围 |
| `p1-12-scan-progress.png` | 真实扫描进度 |
| `p1-13-scan-results.png` | 扫描结果（已确认/候选/已添加） |
| `p1-14-scan-add-matched-device.png` | 扫描结果自动匹配已有设备 |
| `p1-15-scan-added.png` | 保存后标记「已添加」 |
| `p1-16-home-device-services.png` | 首页计数、分类与关联服务 |
| `p1-17-custom-url-webview.png` | 迁移后的自定义 URL 服务可打开 |
| `p1-18-persisted-device-link.png` | 重启后设备关联与数据仍在 |
| `p1-19-settings.png` | 版本 0.3.0、设备管理计数 |

### HTTP 身份验证（0.4.0）

| 文件 | 内容 |
| --- | --- |
| `p2-01-home-after-upgrade.png` | 0.4.0 覆盖安装后数据保留 |
| `p2-02h-ready.png` | 添加自定义 URL 的认证测试服务 |
| `p2-04-home-with-auth-service.png` | 首页出现 Padavan-Auth（5 个服务） |
| `p2-05-auth-dialog.png` | 应用内 HTTP 认证弹窗（服务/host/realm） |
| `p2-07-auth-retry.png` | 错误密码后重新弹窗并提示 |
| `p2-09-auth-success.png` | 正确密码后加载受保护页面 |
| `p2-10-remembered-auto-login.png` | 记住凭据后重启自动登录 |
| `p2-11-service-credentials.png` | 服务编辑页查看已保存凭据 |
| `p2-11-service-credentials-deleted.png` | 删除凭据后的空状态 |
| `p2-12-removed-credential-reprompt.png` | 删除凭据并重启后重新认证 |
| `p2-13-auth-cancelled.png` | 取消认证，停留在 401 页面 |
| `p2-14-html-login-no-auth-dialog.png` | 普通 HTML 表单登录页不弹认证框 |
| `p2-15-api401-no-auth-dialog.png` | 普通 401 API 不弹认证框 |
| `p2-16-not-remembered-reprompt.png` | 未勾选记住，重启后重新认证 |

### P0 历史截图

| 文件 | 内容 |
| --- | --- |
| `p0-01-empty-home.png` | 全新安装：0 服务、0 收藏、分类全 0 |
| `p0-02-add-service-form.png` | 手动添加服务表单 |
| `p0-03-home-with-service.png` | 添加后首页计数与分类更新 |
| `p0-04-webview-loaded.png` | 真实 WebView 加载局域网 HTTP 页面 |
| `p0-05-webview-toolbar.png` | 沉浸工具栏 |
| `p0-06-webview-navigation.png` | 网页内部跳转 |
| `p0-07-home-online.png` | 页面加载成功后状态变「在线」 |
| `p0-08-persisted-after-restart.png` | 重启后数据仍在 |
| `p0-09-discover.png` | 当前网络、CIDR、扫描范围 |
| `p0-10-scan-progress.png` | 扫描进度与取消 |
| `p0-11-scan-results.png` | 真实扫描结果 |
| `p0-12-scan-cancelled.png` | 取消扫描 |
| `p0-13-add-from-scan.png` | 从扫描结果预填添加 |
| `p0-14-home-two-services.png` | 扫描结果添加后的首页 |
| `p0-15-settings.png` | 设置页 |
| `p0-16-devices-empty.png` | 设备空状态 |
| `p0-17-device-form.png` | 新建设备 |
| `p0-18-device-created.png` | 设备列表 |
| `p0-19-device-detail-empty.png` | 设备详情空关联 |
| `p0-20-device-with-service.png` | 设备关联服务 |
| `p0-21-device-deleted.png` | 删除设备后服务未级联删除 |
| `p0-22-duplicate-url-error.png` | 重复 URL 拦截 |
| `p0-23-permission-denied.png` | 拒绝权限后的明确提示 |
| `p0-24-home-final.png` | 最终首页（3 个真实添加的服务，删除前） |
| `p0-25-service-deleted.png` | 服务删除确认后计数与列表更新 |
| `p0-26-service-edit.png` | 服务操作菜单中的编辑表单 |
| `p0-27-permission-recovered.png` | 授权后点「重试」清除权限提示 |

## 已知限制

- 当前只在 Android 模拟器验证，未在物理手机/真实家庭网络测试。
- mDNS/SSDP 在模拟器网络中未返回结果（0 条），端口扫描正常；真实网络可能不同。
- 模拟器虚拟网络 `10.0.2.3` 对所有端口都有响应，导致扫描结果数量偏多；App 只如实记录 HTTP 响应，不伪造结果。
- 当前交付目标为 Android；未提供 Web 构建。代码中的非 Android WebView 分支只显示平台不支持提示，不加载演示页面。
- 在线状态只来自扫描确认或 WebView 页面加载结果，没有后台定时健康检查。
- 设备删除只解绑服务；暂不提供批量重新分配。
- 扫描结果只能关联已存在设备，暂不提供「从扫描结果一键新建设备」的独立表单；可先新建设备再重试添加。
- 服务名称建议仅覆盖常见端口，未知端口显示「端口 N」，不做服务指纹识别。
- 未实现导入/导出、iCloud/云同步、iOS 端。
- APK 为 debug 签名；release 正式签名、混淆、上架元数据未配置。
- 未在真实 Padavan 设备上测试；HTTP 认证使用标准 Basic Auth 测试服务器验证。
- 认证依赖系统 WebView 支持的方案，当前实测 Basic；Digest/NTLM 等未逐项验证。
- 不提供生物识别解锁或主密码；凭据由 Android Keystore 保护，确认凭据是否被系统锁屏保护取决于设备。
- 认证失败时不校验服务端身份（局域网自签证书），仅按 host 严格匹配。
