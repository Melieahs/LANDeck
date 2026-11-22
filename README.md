# LANDeck

本地优先的局域网 Web 服务启动器。当前版本以设备为中心管理服务。接手开发先读 [HANDOFF.md](HANDOFF.md)。

当前版本以设备为中心管理服务：

- 先添加设备（名称 + 地址），设备下的服务只需填端口，URL 自动生成
- 设备地址修改后，所有关联服务的 URL 自动更新；自定义 URL 不受影响
- 设备详情页提供「＋ 添加服务」快捷表单，默认 HTTP、端口即核心输入
- 端口自动建议名称（如 8096 → Jellyfin），名称始终可修改
- 旧版完整 URL 数据自动迁移：能匹配设备的转为设备关联，否则保留为自定义 URL

- 首次安装零服务、零收藏、零设备，空状态引导添加或扫描
- 首页收藏支持点「编辑」后拖动自定义排序，顺序持久化到本地
- 手动添加服务，URL 支持 IP / 域名 / 端口 / HTTP / HTTPS / 路径 / Query
- Sembast 本机数据库持久化，重启 App 后数据仍在
- 两阶段局域网发现：先发现设备（mDNS / SSDP / 子网活跃主机），再在设备详情里只扫描该设备的服务端口
- 扫描结果只是候选，必须由用户确认后才会写入数据库
- 设备 CRUD；删除设备只解绑服务，不级联删除
- 真实 Android 系统 WebView，加载数据库中的 URL；Cookie 由系统 WebView 持久化
- HTTP Authentication（Basic 及系统 WebView 支持的方案）：应用内凭据弹窗、失败重试、取消不循环、可选 Keystore 加密记住
- Material 3 全局视觉体系：浅色 / 深色 / 跟随系统，支持 Material You 动态取色与品牌色回退
- WebView 与原生模块页共用顶栏：左上角退出、服务名 + 模块名/主机副标题、后退、前进、更多、最右侧切换服务；切换服务会保留已打开的页面（最多 4 个后台标签），切回不重载；刷新在「更多」菜单里，沉浸模式也从「更多」进入
- 真实 WebView 下载：拦截下载链接 / Content-Disposition，M3 确认后经 SAF 选择保存位置，前台服务流式写入
- 下载继承当前网页 Cookie、会话和可用的 HTTP Basic 凭据；下载管理支持进度、取消、重试、打开、分享、删除记录
- 真实网页上传：系统文件选择器支持单文件/多文件、MIME/扩展名与取消，URI 直接回传 WebView
- 首页搜索提交后进入独立搜索页，同时检索设备与服务
- 双模式服务：服务可关联已安装的原生模块；在服务设置中选择「默认打开方式」（Web / 原生）。服务内切换只影响当前页面，重新打开仍按默认方式；未关联模块时只能使用 Web，不复制服务记录
- 内置「服务概览」模块；Padavan WAN 控制不再内置，改为可导入的声明式插件示例 `examples/native-modules/padavan-wan/plugin.json`
- 可导入原生模块插件：设置 → 原生模块 → 导入 `.json` / `.zip` 声明式插件；插件不执行代码，只能访问关联服务。格式见 `docs/native-modules.md`
- 发现页「模块插件」：从 LANDeck 仓库的 `examples/native-modules/index.json` 读取插件列表，下载并确认后安装
- WebView「切换服务」按最近使用排序，支持搜索和同名设备上下文；有后台页面的服务用绿点标明存活状态，退出查看器时统一关闭
- 首页统计可直接进入「全部服务」和「设备管理」；设备分类按真实设备数量统计
- 设置「数据存储」二级页：FTP 备份、JSON 导入/导出、密码管理
- 密码按主机 + 端口隔离，网页登录与 HTTP 认证凭据统一查看/删除
- 手机优先的现代 Android 原生观感

## 技术栈

- Flutter 3.50.0 / Dart 3.14.0
- Material 3（`material_ui`）
- `webview_flutter` 4.14.1
- `dynamic_color` 2.1.0（Material You 动态取色）
- `flutter_secure_storage` 11.2.0（Android Keystore + AES-GCM）
- `sembast` 3.10.1 + `sembast_web` 2.4.7
- `network_info_plus` / `multicast_dns` / `permission_handler`
- Android 原生 `DownloadService`（前台 `dataSync`）+ SAF `ACTION_OPEN_DOCUMENT` / `ACTION_CREATE_DOCUMENT`
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

- `dist/LANDeck-0.9.3.apk`（约 56 MB，含 arm64-v8a / armeabi-v7a / x86_64）
- 构建产物：`build/app/outputs/flutter-apk/app-release.apk`
- 包名 `com.example.landeck`，版本 `0.9.3+28`
- SHA-256：以最终构建产物为准
- 当前使用 Flutter 默认 debug 签名，可直接安装测试，不适合直接上架

> `permission_handler_android 13.0.2` 要求编译 SDK ≥ 37，因此 `compileSdk = 37`；`targetSdk` 保持 36。target 36 下局域网访问由 INTERNET 隐式允许，不声明/请求 `ACCESS_LOCAL_NETWORK`。

## 项目结构

```text
lib/
├── main.dart                         # 启动、打开数据库、加载仓库
├── app.dart                          # MaterialApp / AppScope / 路由
├── core/
│   ├── app_scope.dart                # 仓库的 InheritedNotifier
│   ├── theme/                        # M3 浅/深色主题、自适应色板、主题持久化
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
│   ├── device_discovery.dart         # 阶段 1：mDNS + SSDP + 子网活跃主机
│   ├── device_port_scanner.dart      # 阶段 2：单设备端口 + HTTP/HTTPS 验证
│   ├── download_center.dart          # 下载任务队列 / 状态恢复 / 系统桥接
│   ├── download_probe.dart           # HEAD/GET 探测、附件与认证 challenge
│   ├── download_request_headers.dart # Cookie / Basic Auth / Referer
│   ├── download_utils.dart           # 文件名、MIME、风险类型、下载判定
│   ├── native_download_bridge.dart   # 下载与 SAF 文件选择 MethodChannel
│   └── multicast_lock.dart           # Android MulticastLock 通道
├── pages/
│   ├── main_shell.dart               # 底部导航 + IndexedStack
│   ├── home/                         # 首页与收藏/分类/全部服务组件
│   ├── category/                     # 分类筛选
│   ├── discover/                     # 阶段 1：发现设备
│   ├── services/service_editor_page.dart
│   ├── devices/                      # 设备列表/详情/编辑、单设备端口扫描
│   ├── webview/                      # WebView 顶栏、服务切换、下载与认证
│   ├── downloads/downloads_page.dart # 下载任务管理
│   └── settings/
└── widgets/                          # 服务行、图标、状态点、底部导航
```

数据库 store：

- `services`：id、name、deviceId、protocol、port、path、customUrl、category、icon、isFavorite、sortOrder、healthCheckEnabled、lastStatus、lastCheckedAt、createdAt、updatedAt
- `devices`：id、name、deviceType、primaryAddress、icon、notes、sortOrder、createdAt、updatedAt
- `meta/schema`：数据库结构版本（当前 v2）

`Service` 不保存设备 IP。有关联设备且无 `customUrl` 时，URL 由
`device.primaryAddress + protocol + port + path` 动态生成；`customUrl` 存在时优先使用。
`lastStatus` 默认为空；只有在真实扫描确认或 WebView 真正加载成功/失败后才写入在线/离线，不再伪造状态。该字段仅保留在数据层，界面不再展示在线/离线指示（扫描结果不够可靠）。

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

## 两阶段发现

### 阶段 1：发现设备

入口：底部「发现」。

- **网络信息**：`network_info_plus` 读取 Wi-Fi IPv4 与子网掩码；只扫描当前 Wi-Fi 网段，不跨 VPN/其他接口。
- **mDNS**：查询 `_http._tcp`、`_https._tcp`、`_ssh._tcp`、`_smb._tcp`、`_workstation._tcp`、`_device-info._tcp`、`_airplay._tcp`、`_googlecast._tcp`、`_home-assistant._tcp`、`_printer._tcp`，通过 SRV/A 记录获得主机名与 IP；Android 端持有 `MulticastLock`。
- **SSDP / UPnP**：向 `239.255.255.250:1900` 发 M-SEARCH，读取 `LOCATION` 描述并尽量解析 friendlyName / manufacturer / modelName / deviceType；只接受本网段响应。
- **活跃主机**：对当前子网主机做有限 TCP 存活探测（常见 80/443/22/445/548），只用于判断“主机活跃”，不据此认定 NAS/路由器类型。
- **结果**：按 IP 合并来源，显示名称（未知时 IP）、类型（未识别保持「未知设备」）、来源、已添加状态；支持多选、编辑名称/类型/地址/图标后添加设备。设备发现阶段不扫描服务端口、不自动添加服务，也不要求先发现 Web 服务。
- **模块插件**：发现页读取 LANDeck 仓库 `examples/native-modules/index.json`，列出可安装的声明式原生模块；下载清单、展示请求并确认后安装，流程与本地导入一致。
- 支持进度、取消、错误提示；mDNS/SSDP 在当前模拟器网络无响应时，仍会通过活跃主机发现兜底，并明确标注来源。

### 阶段 2：扫描该设备的服务端口

入口：设备详情页「扫描该设备的服务端口」。

- 只扫描当前设备的一个 IP，不再对全网段做端口扫描。
- 端口：`80, 443, 8000, 8080, 8443, 3000, 5000, 5001, 9090, 9443, 8096, 8920, 9000, 9091, 8989`。
- 先 TCP 连接；对开放端口再做 HTTP/HTTPS 验证，接受局域网自签证书，读取状态码、Server、`<title>`。
- 分类：`Confirmed HTTPS`、`Confirmed HTTP`、`Candidate`（TCP 开放但未确认 HTTP）、`Open Port`。401/403/404 等 HTTP 响应仍视为已确认 Web 服务。
- 结果可筛选、取消、重扫；添加时打开服务编辑表单（设备已填、端口/协议预填），用户确认后才写入数据库；已存在的 URL 会标记「已添加」，不会重复创建。
## HTTP 身份验证

- 使用系统 WebView 的 `onHttpAuthRequest` / `HttpAuthHandler.proceed`，不重建 WebView、不重新打开页面。
- 服务地址（host）必须与当前服务 URL 的 host 完全一致，否则取消请求并提示；不会把凭据发给第三方域名。
- 凭据按 `serviceId + host + realm` 绑定；默认不记住。勾选「记住登录信息」后使用 Android Keystore 加密保存，可在「编辑服务 → 已保存的登录信息」删除。
- 密码错误时重新弹出对话框并预填用户名、提示“认证失败，请检查用户名和密码”；同一 scope 只自动重试一次，避免死循环。
- 点「取消」只取消本次 challenge，不会自动反复弹出；刷新或重新进入服务可重新认证。
- 普通 HTML 表单登录页、无 `WWW-Authenticate` 的 401 响应不会触发该弹窗。
- 不在 URL 中写入凭据；不打印用户名/密码日志。

### 网页登录信息填充（自动保存 / 自动填充）

- 登录成功后自动弹出「保存登录信息？」确认框；同一服务、主机和端口下可以保存多个账号。
- WebView「更多操作」仍保留「保存当前登录信息」和「填充登录信息」作为手动入口。
- 自动保存只在用户提交登录表单时触发，只读取当前页面里可见的用户名/密码输入框，先弹出确认框，明确显示服务、host 和用户名；用户确认后才写入加密存储，不自动保存、不自动提交表单。
- 每个服务可在「编辑服务 → HTTP 登录凭据」中设置填充方式：自动填充（默认账号直接填）、填充前先选择（每次弹账号列表）、不自动填充；并可用星标指定默认账号（不指定时用最近保存的账号）。
- 填充时按「服务 + host」匹配已保存凭据，多个账号时默认账号排在第一位并带「默认」标记；只填充输入框，不点击登录按钮。
- 网页登录凭据与 HTTP Basic 凭据共用加密存储，但使用独立 scope（`web-form`），在「编辑服务 → 已保存的登录信息」中会显示为「网页登录」，可按账号单独删除。
- HTTP 认证对话框同时开启了系统密码管理器 Autofill 提示（用户名/密码），可使用系统保存的密码填充。
- 支持未使用 `<form>` 的 SPA 登录页（例如 CasaOS）、开放式 Shadow DOM 和同源 iframe；页面异步渲染后会继续尝试填充。
- 限制：不处理跨域 iframe 内的登录表单；网页账号按“主机 + 端口”分别保存（如 `192.168.1.12:80` 与 `192.168.1.12:5666` 互不影响），同一端口可保存多个用户名；页面重定向到同主机的其他端口时，会按实际页面端口取用对应账号；旧版本仅按主机保存的账号不会自动套用到新端口，需要在该端口重新保存一次。

## WebView 下载与上传

### 下载

- **识别**：普通页面导航继续在 WebView 打开；明确的文件扩展名、`/download` 路径、`Content-Disposition: attachment` 才进入下载流程。扩展名不明确的路径会先做 HEAD/短 GET 探测，避免把普通页面误判为文件。
- **确认**：M3 对话框显示文件名、来源服务、host、MIME、大小和保存位置说明；APK/可执行/固件等风险类型给出明确提示，但不宣称病毒扫描，也不自动打开或安装。
- **保存**：`ACTION_CREATE_DOCUMENT` 让用户选择位置，不申请宽泛存储权限；文件名经过路径分隔符、控制字符和超长截断清理；同名文件由 SAF/系统处理，App 不覆盖已有文件。
- **传输**：Android 前台服务 `DownloadService`（`dataSync`）用 `HttpURLConnection` 64KB 流式写入，不上传整个文件到内存；通知显示真实进度，完成后可点击打开；离开 WebView 或切到后台时任务由前台服务继续。
- **认证与 Cookie**：下载请求由 `DownloadRequestHeaders` 注入 WebView Cookie、UA、Referer；需要 Basic Auth 时，若探测到 401 + `WWW-Authenticate: Basic`，弹出 M3 认证框，成功后只用内存中的会话凭据重试，勾选记住才写入 Android Keystore。凭据严格按 service + host + realm 绑定，不写入 URL，不打印日志。
- **状态**：任务持久化在 Sembast，状态为 Pending / Downloading / Completed / Failed / Cancelled；支持进度、取消、失败重试、打开、分享、复制链接和删除记录。应用异常退出后，遗留的进行中任务会标记失败并允许重试。

### 上传

- 通过 `AndroidWebViewController.setOnShowFileSelector` 接管网页 `input[type=file]`。
- `ACTION_OPEN_DOCUMENT` 支持单文件/多文件、`accept` MIME 与常见扩展名映射；返回 content URI 并保留读权限。
- `切换服务` 面板按最近使用排序，支持名称/设备/IP 搜索。
- `ACTION_CREATE_DOCUMENT` 支持网页的 save 模式；用户取消时回传空列表，WebView 不会悬挂回调，可连续再次选择。
- 文件不复制到 App 私有目录，不整文件读入内存；大文件由系统文件提供程序流式读取。`capture` 当前退化为普通文件/媒体选择，不额外申请相机权限。

## 验证结果

- `flutter analyze`：No issues found
- `flutter test`：62 tests passed
- `flutter build apk --release`：成功，约 57.5 MB（0.9.3+28）
- Android 模拟器（Android 36 x86_64，1080×2400）实测：
  - 首次安装 0 服务、0 收藏、0 设备，空状态正常
  - 手动添加 → 首页计数/分类/收藏更新 → 强制停止再启动仍存在
  - 真实 WebView 加载本机 HTTP 测试页，内部跳转、返回、顶栏、服务切换正常
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
  - Material 3：首页、设备列表/详情、服务编辑、扫描、设置、WebView 工具栏/服务切换/更多操作/HTTP 认证弹窗均使用统一 M3 组件
  - 浅色 / 深色 / 跟随系统切换正常，强制停止重启后主题选择保持
  - 浅色下 WebView 状态栏图标、返回图标、工具栏与弹窗对比度正常
  - M3 发现页真实扫描 `10.0.2.16/24`：68 个候选、4 个已确认，来源/HTTP 状态/已添加标记正常，可取消
  - 两阶段发现：真实发现 5 台活跃主机；添加其中一台为设备后进入设备详情
  - 单设备扫描 `10.0.2.2`：确认 80/3000/8000/8080 四个 Web 服务，已存在的 8080 正确显示「已添加」，未重复添加
  - 快捷添加：只填端口 8080，自动生成 `http://10.0.2.3:8080`
  - Material You 动态取色开关可即时切换；关闭后回到 LANDeck 品牌蓝色
  - WebView 顶栏返回键按网页历史后退，退到底后返回上一页
  - 真实下载 `sample.txt`（440 B）、`中文报告.txt`（660 B，UTF-8 Content-Disposition）、`large.bin`（20 MB）均完成并写入系统 Downloads
  - Basic Auth 保护的 `auth.txt`：下载前弹出 M3 认证框，登录后保存为 `secure-report.txt`（460 B）
  - 网页上传：单文件 1 个、多文件 2 个均被测试服务器实际接收
  - 下载管理页显示真实任务、真实大小/状态；删除记录、复制链接、重试入口可用

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

### 动态取色 / 两阶段发现（0.6.0）

| 文件 | 内容 |
| --- | --- |
| `s1-01-home-dynamic.png` | Material You 动态取色首页 |
| `s1-08-settings-dynamic.png` | 外观设置：主题 + 动态颜色开关 |
| `s1-19-dynamic-color-off.png` | 关闭动态取色后的品牌蓝色 |
| `s1-02-discover-devices.png` | 发现设备：网络信息与扫描入口 |
| `s1-03-discover-progress.png` | 阶段 1 扫描进度 |
| `s1-04-discover-results.png` | 活跃主机结果（来源、未知类型、添加） |
| `s1-05-add-discovered-device.png` | 从发现结果预填新建设备 |
| `s1-06-device-form-filled.png` | 设备名称/类型/地址/图标 |
| `s1-07-device-detail.png` | 新设备详情 |
| `s1-09-quick-add.png` | 设备内快捷添加：只填端口 |
| `s1-10-device-detail-service.png` | 快捷添加后的关联服务 |
| `s1-11-devices.png` | 设备列表（真实服务数量） |
| `s1-12-device-detail-scan-entry.png` | 设备详情「扫描该设备的服务端口」 |
| `s1-13-device-scan.png` | 单设备端口扫描 |
| `s1-14-device-scan-results.png` | 扫描结果与「已添加」去重 |
| `s1-15-add-from-device-scan.png` | 结果预填服务表单 |
| `s1-16-webview-exit-toolbar.png` | 六按钮工具栏：后退/前进/刷新/服务/更多/退出 |
| `s1-17-webview-auth.png` | HTTP Basic Auth 成功后加载真实页面 |
| `s1-18-webview-exited-home.png` | 点击「退出」直接回到首页 |

### Material 3 改版（0.5.0）

| 文件 | 内容 |
| --- | --- |
| `m3-01-home-light.png` | 浅色首页：M3 AppBar、SearchBar、统计、收藏、设备、分类、服务列表 |
| `m3-02-settings-light.png` | 浅色设置页：分组、主题选择器 |
| `m3-03-settings-dark.png` | 深色设置页 |
| `m3-04-home-dark.png` | 深色首页 |
| `m3-05-service-form-dark.png` | M3 服务编辑/完整添加表单 |
| `m3-06-devices-dark.png` | M3 设备列表 |
| `m3-07-device-detail-dark.png` | 设备详情与关联服务 |
| `m3-08-quick-add-dark.png` | 设备内快捷添加：端口 8096 → Jellyfin |
| `m3-09-home-light.png` / `m3-14-persisted-light.png` | 浅色首页；重启后主题保持 |
| `m3-15-webview-light-final.png` | 浅色 WebView：状态栏、手柄、真实页面 |
| `m3-11-webview-toolbar-light.png` | M3 浮动工具栏 |
| `m3-12-more-sheet-light.png` | M3 更多操作 Bottom Sheet |
| `m3-13-auth-dialog-light.png` / `m3-17-auth-dialog-dark-final.png` | M3 HTTP 认证弹窗（浅色/深色） |
| `m3-18-auth-success-dark.png` | 深色下认证成功，加载受保护页面 |
| `m3-19-discover-dark.png` | M3 发现页：网络信息、扫描范围与权限说明 |
| `m3-20-scan-progress-dark.png` | M3 扫描进度与取消 |
| `m3-22-scan-results-dark.png` | M3 真实扫描结果（已确认/来源/HTTP 状态/已添加） |

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

### 下载与上传（0.7.0）

| 文件 | 内容 |
| --- | --- |
| `t2-12-download-manager.png` | 下载管理：认证下载成功与历史任务 |
| `t2-49-slow-download-dialog.png` | M3 下载确认：文件名/来源/MIME/大小/风险提示 |
| `t2-42-upload-success.png` | 网页上传单文件成功（服务器实际回执） |
| `t2-46-upload-multi-success.png` | 网页上传多文件成功（2 个） |
| `t2-45-upload-two-form.png` | 系统文件选择器选中 2 个文件后的网页表单 |
| `t3-01-home-0.7.0.png` | 0.7.0 最终版本首页（真实数据） |

### P0 历史截图

| 文件 | 内容 |
| --- | --- |
| `p0-01-empty-home.png` | 全新安装：0 服务、0 收藏、分类全 0 |
| `p0-02-add-service-form.png` | 手动添加服务表单 |
| `p0-03-home-with-service.png` | 添加后首页计数与分类更新 |
| `p0-04-webview-loaded.png` | 真实 WebView 加载局域网 HTTP 页面 |
| `p0-05-webview-toolbar.png` | 沉浸工具栏 |
| `p0-06-webview-navigation.png` | 网页内部跳转 |
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
- 在线/离线指示已从界面移除（扫描与页面加载结果不足以代表真实在线状态）；状态字段仅保留在数据层。切换服务列表的绿点表示「有后台页面」，不是网络状态。
- 设备删除只解绑服务；暂不提供批量重新分配。
- 扫描结果只能关联已存在设备，暂不提供「从扫描结果一键新建设备」的独立表单；可先新建设备再重试添加。
- 服务名称建议仅覆盖常见端口，未知端口显示「端口 N」，不做服务指纹识别。
- 未实现导入/导出、iCloud/云同步、iOS 端。
- APK 为 debug 签名；release 正式签名、混淆、上架元数据未配置。
- 未在真实 Padavan 设备上测试；HTTP 认证使用标准 Basic Auth 测试服务器验证。
- 认证依赖系统 WebView 支持的方案，当前实测 Basic；Digest/NTLM 等未逐项验证。
- 不提供生物识别解锁或主密码；凭据由 Android Keystore 保护，确认凭据是否被系统锁屏保护取决于设备。
- 认证失败时不校验服务端身份（局域网自签证书），仅按 host 严格匹配。
- 下载/上传只在 Android 模拟器验证；未在物理手机、真实 NAS 的厂商下载接口上测试。
- 下载认证目前实测 Basic；Digest/NTLM 等依赖系统 WebView 的方案未逐项验证。
- 后台下载使用前台 Service；已验证系统下载服务与通知权限，但未做进程被系统杀死、长时间断网重连的压力测试。
- 不提供暂停/断点续传；取消后需重新下载。
- 网页 `capture` 不直接调用相机，统一走系统文件/媒体选择器。


## iOS / iPadOS（Material 3）

iOS 端当前直接复用与 Android 相同的 Material 3 页面、主题和业务逻辑，不再使用 Cupertino / Liquid Glass 实验界面。

- iOS 入口：`lib/app.dart` 不再按平台分流，直接使用 `LanDeckApp`。
- 共享：数据模型、Sembast 数据库、URL 生成、仓库逻辑、Material 3 主题。
- `ios/Runner/Info.plist` 已包含本地网络权限描述与 Bonjour 服务类型。
- 构建：Linux 只能执行 `flutter analyze` / `flutter test`，不能编译 iOS；`.github/workflows/ios-simulator.yml` 在 GitHub Actions macOS Runner 上构建未签名真机 IPA（`flutter build ios --release --no-codesign`）并上传 artifact。
- 当前可用：WKWebView 网页浏览、导航、服务切换、Cookie/Session、HTTP Basic Auth、文件上传。
- iOS 下载：新增 Swift `URLSession` 下载桥接，文件保存到「文件 App / LANDeck / Downloads」，支持取消、打开和分享；Basic Auth、Cookie 和私有网段自签名证书沿用 WebView 会话。
- 已接入：Bonjour/mDNS 发现、iOS 本地网络权限处理、单设备端口扫描、FTP 备份/恢复。
- 当前限制：签名 IPA/TestFlight 仍需 Apple Developer 账号；Liquid Glass 实验代码保留但未启用。
