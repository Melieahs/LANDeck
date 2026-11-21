# LANDeck 开发交接文档

> 交接时间：2026-11-21  
> 当前分支：`feature/native-modules`  
> 当前版本：`0.9.3+28`  
> 代码 HEAD：`d522c33 test(native): cover imported module rendering`  
> 文档状态：已提交（最新提交以 `git log` 为准）  
> 工作区：干净（本文档提交前）  
> 远端：`git@github.com:Melieahs/LANDeck.git`

本文档面向下一个接手的开发者/会话。先读“当前状态”和“开发流程”，再按“下一步”继续。所有历史实现细节以仓库代码和 `docs/` 为准。

---

## 1. 当前状态（TL;DR）

LANDeck 是一个 Flutter 的局域网服务启动器：

- Android 与 iOS 共用同一套 Dart 业务/数据/UI。
- UI 已统一为 **Material Design 3**，支持浅色/深色/跟随系统、Android Material You 动态取色。
- 数据完全来自本地 Sembast，无账号、无云端、无 Demo 数据。
- 服务以设备为中心：先建设备，再在设备下快速添加服务；设备地址变化时关联服务 URL 自动更新。
- 已实现真实 WebView、HTTP Basic Auth、网页密码保存/自动填充、下载、上传、局域网两阶段发现、设备端口扫描、FTP 备份/恢复、原生模块双模式、声明式插件导入（Padavan 作为插件示例，不再内置），以及发现页的仓库插件源安装。

当前验证结果：

- `flutter analyze`：通过，`No issues found!`
- `flutter test`：**83 个测试全部通过**
- Android release APK：`dist/LANDeck-0.9.3.apk`，58,748,385 字节（约 56 MB），
  SHA-256 `8881b49816bb22dbd46cea412efd1ba5307f7d76d7630160a22abb7c44c50396`
- iOS：CI 生成 **unsigned IPA**（不能直接安装）；本轮 `d522c33` 的 CI run 见 §11。
- 本次插件导入功能：导入 UI、预览、持久化已实机验证；**把导入插件关联到服务并打开插件页的完整设备链路尚未手工跑通**（widget test 已覆盖渲染/存储/注册）。

---

## 2. 技术栈与环境

| 项目 | 值 |
|---|---|
| Flutter | 3.50.0 stable |
| Dart | 3.14.0 |
| UI 库 | `material_ui`（Flutter 3.50 对 `flutter/material.dart` 的替代） |
| 状态/依赖注入 | `AppScope`（InheritedWidget）+ 显式 repository |
| 数据库 | `sembast`，schema v2 |
| WebView | `webview_flutter` / `webview_flutter_android` / `webview_flutter_wkwebview` |
| 安全存储 | `flutter_secure_storage`（Android Keystore / iOS Keychain） |
| 动态取色 | `dynamic_color`（Android 12+） |
| 网络 | `http`、`multicast_dns`、`network_info_plus` |
| FTP | `ftpconnect` |
| 文件选择/分享 | `file_picker`、`share_plus` |
| Android | compileSdk 37 / targetSdk 36 / minSdk 24，JDK 21 |
| 包名 | `com.example.landeck` |

本机路径：

```bash
export PATH=/home/cyu/development/flutter/bin:$PATH
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export ANDROID_HOME=/home/cyu/Android/Sdk
export PATH=$ANDROID_HOME/platform-tools:$PATH
```

项目目录：`/home/cyu/Projects/LANDeck`

本机**没有 macOS/Xcode**，不能本地编 iOS；iOS 只能走 GitHub Actions。Android 使用模拟器 `landeck_test`（1080×2400，Android 16/API 36）。

---

## 3. 仓库与分支

```text
main
└── feature/ios                 # iOS 主开发线
    ├── feature/ios-settings-cleanup
    ├── feature/search-page
    ├── feature/toolbar-quick-actions
    └── feature/native-modules   # 当前分支
```

当前关键提交（新→旧）：

```text
d522c33 test(native): cover imported module rendering
0ffa70c docs(native): fix plugin example JSON
1b5c404 feat(native): import declarative module plugins
3f2dc2a feat(service): configure default web/native mode; remove Padavan confirms
38442c2 test(native): cover Padavan login surface and harden action parsing
c7b0a90 feat(native): add Padavan WAN control module
35559f6 test(service): cover native module viewer integration
3537105 ci: build native modules branch
d72e191 feat(service): add native module dual-mode framework
```

`feature/android-internal-files` 是已经放弃的 Android 内部文件管理实验（commit `6a37c36`），**不要继续**，除非用户重新要求。

---

## 4. GitHub 凭据与推送

### 4.1 远端

```text
origin  git@github.com:Melieahs/LANDeck.git
```

仓库：`Melieahs/LANDeck`。没有配置 Personal Access Token，也没有安装 `gh` CLI。

### 4.2 部署密钥（本机已有）

- 私钥：`/home/cyu/.ssh/landeck_deploy`（权限 600）
- 公钥：`/home/cyu/.ssh/landeck_deploy.pub`
- 类型/指纹：`ED25519`，`SHA256:6IHrn+XyCHbSCJnjSraoUHp45i74Os9abGqzObiZp0Q`
- 该公钥已作为 **Deploy Key（写权限）** 添加到 GitHub 仓库。

推送命令（必须显式指定 key，默认 SSH key 未被授权）：

```bash
cd /home/cyu/Projects/LANDeck
GIT_SSH_COMMAND='ssh -i /home/cyu/.ssh/landeck_deploy -o IdentitiesOnly=yes' \
  git push git@github.com:Melieahs/LANDeck.git feature/native-modules
```

不要把私钥内容写进仓库、日志或聊天。若换机器，重新生成 key 并在 GitHub
`Settings → Deploy keys` 添加（勾选 write access）。没有权限时 `git push` 会报
`Permission denied (publickey)`。

### 4.3 Git 身份

```text
user.name  = LANDeck Dev
user.email = dev@landeck.local
```

---

## 5. 目录结构

```text
lib/
├── app.dart                    # MaterialApp / theme / route 生成
├── main.dart                   # DB、Repository、Theme、插件、DownloadCenter 初始化
├── core/
│   ├── app_scope.dart          # 全局 repository 注入
│   ├── theme/                  # AppColors / AppTheme / ThemeController
│   └── utils/                  # URL、格式化等
├── data/database/              # Sembast schema v2 + 迁移
├── models/                     # Service / Device / DownloadTask / HttpCredential / ServiceMode ...
├── native/                     # 原生模块接口、注册表、内置模块、Padavan、插件
├── pages/                      # 页面（home/devices/services/webview/settings/...）
├── repositories/               # LanDeckRepository（CRUD、备份导入导出）
├── routes/                     # AppRouter
├── services/                   # 扫描、下载、FTP、密码填充等业务服务
├── widgets/                    # 通用 M3 组件
└── ios/                        # 已停用的 Cupertino/Liquid Glass 实验代码，当前不参与 iOS 运行
```

iOS 当前**直接使用共享 Material 3 UI**（`lib/app.dart` 没有 iOS 分支）。
`lib/ios/` 只是历史实验，不要误接回去，除非用户明确要求 Cupertino。

Android 原生关键文件：

```text
android/app/src/main/kotlin/com/example/landeck/MainActivity.kt
android/app/src/main/kotlin/com/example/landeck/DownloadService.kt
android/app/src/main/AndroidManifest.xml
android/app/src/main/res/xml/file_paths.xml
```

iOS 原生关键文件：

```text
ios/Runner/AppDelegate.swift   # URLSession 下载桥、文件分享、FileProvider 等价能力
ios/Runner/Info.plist          # 本地网络、Bonjour、文件共享声明
```

---

## 6. 数据模型与关键规则

### 6.1 Device

```text
id, name, deviceType, primaryAddress, icon, notes,
sortOrder, createdAt, updatedAt
```

- `primaryAddress` 是 IP / 主机名 / 域名，不带 scheme、端口、路径。
- 删除设备不会删除服务；关联服务会解绑并冻结当前 URL。

### 6.2 Service

```text
id, name, deviceId?, protocol, port?, path?, customUrl?,
category, icon, isFavorite, sortOrder,
healthCheckEnabled, lastStatus?, lastCheckedAt?,
nativeModuleId?, defaultMode,
lastOpenedAt?, createdAt, updatedAt
```

URL 规则：

```text
device.primaryAddress + protocol + port + path
```

- 有 `customUrl` 时优先使用 `customUrl`。
- 设备地址修改后，所有关联服务 URL 自动更新。
- `defaultMode` 只决定“从首页/搜索/设备页打开时用 Web 还是原生”；服务内切换不修改默认值。
- `lastOpenedAt` 用于服务切换器的最近使用排序。

### 6.3 数据库

`schemaVersion = 2`，store：

- `devices`
- `services`
- `downloads`
- `meta`（`theme_mode`、`dynamic_color` 等）

迁移在 `lib/data/database/database_migration.dart`，**不要随意 bump schema**；改模型必须补迁移与测试。

---

## 7. 已实现功能与关键文件

### 7.1 首页 / 搜索 / 设备

- 首页：`lib/pages/home/home_page.dart`
- 收藏网格手动排序：点「编辑」进入编辑状态后拖动卡片重排，点「完成」退出，顺序存 `Service.favoriteSortOrder`
- 统计可点击：服务数 → 全部服务页；设备数 → 设备页
- 首页不再提供排序菜单与分类筛选 chips：服务与设备列表固定按名称排列；收藏与设备卡片名称最多两行，超出才省略
- 界面不再展示在线/离线状态（扫描结果不准）；`Service.lastStatus` 仅用于排序与插件字段，切换服务列表的绿点表示「有后台页面」
- 搜索入口 → `lib/pages/search/search_page.dart`
- 设备分类已并入设备模块，按 `DeviceType` 统计设备数
- 设备详情：`lib/pages/devices/device_detail_page.dart`
- 快捷添加服务：`lib/pages/devices/device_detail_page.dart` → `ServiceEditorPage(quickMode:true)`

### 7.2 服务表单

`lib/pages/services/service_editor_page.dart`

- 完整模式/快捷模式
- 端口建议、自动名称、HTTPS 自动切换
- 自定义 URL
- 设备关联
- 原生模块关联 + 默认打开方式
- 已保存登录凭据管理

### 7.3 WebView

`lib/pages/webview/web_view_page.dart`

- 与原生模块页一致的顶栏：左上角退出（直接离开 WebView）、服务名 + 模块名/主机副标题、后退、前进、更多、最右侧切换服务
- 刷新放入「更多」菜单；不再有 Web/原生 大切换器，模式切换在「切换服务」面板里完成
- 原生模块页同样去掉底部切换器，顶栏最右为切换服务
- 切换服务是多标签语义：已打开的 WebView 页面保留在后台（LRU 保留 4 个），切回不重载；切换面板用绿点标明有后台页面的服务（存活），退出查看器（Web 或原生页左上角/系统返回）时统一关闭后台标签
- 沉浸模式从「更多」进入，右上角保留更多入口，可随时退出
- HTTP Basic Auth 对话框
- 网页密码自动填充/自动保存提示
- 下载确认 + 系统选择保存位置（Android 走 SAF；iOS 写 App Documents）
- 文件上传（Android 文件选择器；iOS 使用 WKWebView 原生 input）
- Cookie/认证继承、健康状态记录、错误页

### 7.4 发现与扫描

- 阶段一设备发现：`lib/services/device_discovery.dart`
  - mDNS、SSDP、当前子网 TCP 存活探测
  - 结果只是候选，必须用户确认后才建设备
- 阶段二设备端口扫描：`lib/services/device_port_scanner.dart`
  - 只扫单台设备常见 Web 端口
  - TCP + HTTP/HTTPS 验证
  - 确认后才添加服务，按 canonical URL 去重
- iOS 本地网络权限：没有运行时 API；首次 Bonjour/TCP 会触发系统提示。若已拒绝，去
  `设置 → 隐私与安全性 → 本地网络 → LANDeck` 打开。

### 7.5 下载/上传

- Dart：`lib/services/download_center.dart`、`download_probe.dart`、`download_utils.dart`
- Android：`DownloadService.kt`（前台服务、流式、通知、SAF）
- iOS：`AppDelegate.swift` 的 `URLSessionDownloadTask` 桥
- 下载任务持久化在 `downloads` store
- 已知限制：
  - 目录上传在 WebView 中拿不到 `webkitRelativePath`，只能平铺文件；PS5 的目录上传仍可能不满足。
  - APK/固件等风险文件只提示，不扫描/不安装。

### 7.6 密码填充

- `lib/services/web_password_fill.dart`
- `lib/pages/webview/widgets/web_password_dialogs.dart`
- 按 **host:port** 隔离账号（同一 IP 不同端口不共享）
- 自动填充只填空密码框，不自动提交
- 保存必须用户确认；加密存 `flutter_secure_storage`
- 历史 host-only 凭据不再匹配（这是有意的安全/正确性变化）

### 7.7 原生模块

- 接口：`lib/native/native_module.dart`
- 注册表：`lib/native/native_module_registry.dart`（默认只注册「服务概览」）
- 内置：`lib/native/builtin/service_overview_module.dart`
- Padavan WAN 控制已从内置模块移除，改为声明式插件示例 `examples/native-modules/padavan-wan/plugin.json`
  - 真实接口 `POST /device-map/wan_action.asp`（Connect / Disconnect / WispReassoc）
  - 状态解析 `/device-map/internet.asp`
  - 插件不设 `confirmText`，用户点击后立即执行（不做二次确认）
  - 导入入口与格式见 7.8；导入后到服务编辑页关联并选择默认打开方式
- 双模式调度：`lib/pages/service/service_viewer_page.dart`
- 原生页：`lib/pages/service/native_service_page.dart`

### 7.8 声明式插件（本轮新增）

格式文档：`docs/native-modules.md`  
示例：`examples/native-modules/http-status/plugin.json`、`examples/native-modules/padavan-wan/plugin.json`

要点：

- 支持 `.json` 或 `.zip`（zip 内 `plugin.json`）
- `schema: 1`，`id` 必须以 `plugin.` 开头
- 只能发同源相对 HTTP 请求；不能写 JS/执行本地代码
- 支持 Basic Auth（凭据加密存储，realm `plugin:<id>`）
- 支持状态字段、最多 8 个动作、最多 16 个字段
- 包大小上限 512 KB；manifest 128 KB
- 导入入口：设置 → 原生模块 → 右上角 `+`
- 发现页插件源：「发现」→「模块插件」读取仓库 `examples/native-modules/index.json`
  （默认 `https://raw.githubusercontent.com/Melieahs/LANDeck/main/examples/native-modules/index.json`）
  - 只接受相对 `.json` 路径，拒绝绝对 URL、`..`、非 HTTP(S)；索引/清单各 128 KB 上限
  - 下载后复用同一确认框，再写入 `native_modules/`
  - 未合并到默认分支的插件在发现页不可见
- 存储：app support `native_modules/`，启动时 `loadAll()` 注册
- 导入模块不能覆盖内置模块

代码：

```text
lib/native/plugin/plugin_manifest.dart
lib/native/plugin/imported_native_page.dart
lib/native/plugin/imported_module_store.dart
lib/native/plugin/plugin_catalog.dart
lib/native/plugin/plugin_install_dialog.dart
lib/pages/discover/plugin_market_section.dart
lib/pages/settings/native_modules_page.dart
examples/native-modules/index.json
```

---

## 8. 构建 / 测试 / 运行

### 8.1 日常检查

```bash
cd /home/cyu/Projects/LANDeck
export PATH=/home/cyu/development/flutter/bin:$PATH

flutter pub get
flutter analyze
flutter test
```

期望：analyze 0 issue；test 79 passed。

### 8.2 Android APK

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
flutter build apk --release

cp build/app/outputs/flutter-apk/app-release.apk dist/LANDeck-<version>.apk
sha256sum dist/LANDeck-<version>.apk
```

安装（保留数据，不要 uninstall）：

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

模拟器：

```bash
emulator -avd landeck_test -no-window -no-audio -no-boot-anim \
  -no-snapshot -gpu swiftshader_indirect -accel on -memory 2048 -cores 2 -no-metrics
```

### 8.3 iOS（必须走 CI）

本机不能 `xcodebuild`、不能 `pod`，也没有 Apple Developer 账号。CI：

```text
.github/workflows/ios-simulator.yml
```

- runner：`macos-26`
- `flutter build ios --release --no-codesign`
- 产物：`LANDeck-unsigned-ipa` artifact（14 天）
- 触发分支：`feature/ios`、`feature/ios-settings-cleanup`、`feature/search-page`、
  `feature/toolbar-quick-actions`、`feature/native-modules`、`main`
- **新建功能分支后，若需要 iOS CI，先在该 workflow 的 branches 列表里加分支名**

查看运行：

```bash
curl -s 'https://api.github.com/repos/Melieahs/LANDeck/actions/runs?branch=feature/native-modules&per_page=1'
```

unsigned IPA **不能直接安装**：需要 Sideloadly/AltStore 重签，或用有 Apple 开发者账号的
Xcode 重新签名。不要向用户宣称“可以直接装”。

### 8.4 测试服务器

本机临时测试服务（重启机器后可能不存在，需要重建）：

```text
/tmp/landeck-transfer-test/server.py    # 端口 8090
  /            上传表单 + 慢速下载入口（测试时临时）
  /web-login   网页登录表单（admin / webpass）
  /files/sample.txt
  /files/chinese.txt
  /files/auth.txt        Basic realm Padavan (admin / landeck2026)
  /files/large.bin       20MB
  /files/slow.bin        8MB 慢速
  /upload
```

Padavan 真实设备：`192.168.1.1`，Basic realm `CR660x`。  
CasaOS：`192.168.1.2`。  
fnOS：`192.168.1.12:5666`。  
PS5 Web File Manager：`192.168.1.50:8888`。  
这些地址是用户家庭网络，离开该网络不可用。

---

## 9. 一轮开发的推荐流程

1. **确认基线与分支**
   ```bash
   git status
   git branch --show-current
   git log --oneline -5
   ```
   从最新 `feature/ios`（或用户指定分支）切新分支；不要直接改 `main`。

2. **先读代码再改**
   - 页面：`lib/pages/...`
   - 业务：`lib/services/...`、`lib/repositories/...`
   - 模型/迁移：`lib/models`、`lib/data/database`
   - 公共 UI：`lib/widgets`、`lib/core/theme`
   禁止新增假数据、Mock fallback、`alert/confirm`。

3. **小步实现**
   - 先改模型/数据库并补迁移测试
   - 再做 repository/业务
   - 再做 UI
   - 保持既有 key/测试可定位

4. **质量门禁**
   ```bash
   flutter analyze
   flutter test
   ```
   两者都通过才构建。不要用“看起来能跑”代替。

5. **先 iOS，后 Android**（用户明确要求）
   - commit + push 触发 iOS CI
   - 等 CI 成功（unsigned IPA artifact）
   - 再 `flutter build apk --release`
   - 记录 APK 大小/SHA-256

6. **版本/文档**
   - `pubspec.yaml` version（当前 `0.9.3+28`）
   - 设置页“关于”版本
   - README 功能/构建结果
   - 需要时补 `docs/`

7. **交付**
   - APK 放 `dist/`
   - 报告：完成内容、验证结果、APK 路径/hash、已知问题
   - 不宣称未执行的测试/未生成的截图

---

## 10. 已知问题 / 限制

### Android

- 仅模拟器验证，没有物理 Android 真机回归。
- release APK 使用 debug 签名；没有正式 keystore。
- 目录上传（`webkitdirectory`）无法保留相对路径，文件会平铺；PS5 等站点可能不接受。
- PS5 一次性 iframe 下载已做 JS 拦截 + 原生下载，但真实 PS5 的最终回归仍建议再测。
- 下载完成弹窗重复问题已在 0.7.4 加 per-page 去重；当前 0.9.3 保留该逻辑，用户未再反馈。

### iOS

- 只有 unsigned IPA；安装需要重签。
- 没有 Mac，无法本地调试；所有 iOS 结论来自 CI + 用户真机反馈。
- 本地网络权限没有运行时状态 API；拒绝后需去系统设置手动开。
- 基础 WebView/HTTP Auth/上传由 `webview_flutter_wkwebview` 提供；下载由 `AppDelegate.swift` 的桥实现。
- `lib/ios/` 是停用的 Cupertino 实验，不要作为当前 iOS UI。

### 插件系统

- 只支持声明式同源 HTTP，不支持任意代码/动态二进制；这是刻意安全边界。
- 没有签名/市场/权限审核；导入前只做格式与来源限制。
- 没有内置图标资源包，图标名映射有限。
- 导入插件页面的真实设备端到端链路尚未完整手工验证。

### 其它

- 首页不再有排序/筛选状态（已移除），分类页面独立保留分类入口。
- FTP 只做备份/恢复，不是文件浏览器；路径已针对 NAS FTP 根目录做兼容，但仍建议用真实 NAS 复测。
- `dist/` 和 `screenshots/` 在 `.gitignore` 中。

---

## 11. 当前 CI / 交付物

- Android：`dist/LANDeck-0.9.3.apk`
  - 58,748,385 bytes
  - SHA-256 `8881b49816bb22dbd46cea412efd1ba5307f7d76d7630160a22abb7c44c50396`
- iOS CI：
  - Actions 页面：https://github.com/Melieahs/LANDeck/actions
  - 每次 push 到受支持分支都会触发；成功后下载 artifact `LANDeck-unsigned-ipa`
  - 最新成功 run `44900196060` 对应 `4affd2a`（修复回退索引条目下载 404），
    artifact 8,604,747 字节；此前 run `44899296418` 对应 `0854bbb`
    （Padavan 插件示例 + 发现页插件源），artifact 8,605,336 字节；
    后续纯文档提交会触发新的 run，以页面最新结果为准
  - 历史 run `44894071777` 对应 `d522c33`

如果 CI 失败：先看 `flutter analyze` / Swift 编译日志；常见问题是 `macos-26` runner 的 Xcode 版本、Swift API 可用性、SPM 依赖。

---

## 12. 下一步建议（按优先级）

1. **完成插件端到端验证（用户手动）**：打开「发现」→「模块插件」，确认列表出现
   `plugin.padavan-wan`，点「安装」并确认；也可继续用本地导入 `examples/native-modules/`
   下的插件。安装后到服务编辑页关联并设默认原生，从首页打开确认状态字段与动作可用；
   Padavan 插件用真实路由器 `192.168.1.1` 验证。
2. **检查 iOS CI `d522c33` 结果**，把 unsigned IPA 链接交给用户；不要在未验证时称“可安装”。
3. **Android 0.9.3 冒烟**：安装 `dist/LANDeck-0.9.3.apk`，确认发现页插件源、导入插件列表、
   双模式开关、Padavan 插件入口不崩溃。
4. **继续 iOS 功能补齐**：iPad 适配、原生分享/文件打开体验、发现页细节；
   注意 iOS 仍复用 Material 3。
5. **目录上传**：若用户坚持 PS5 目录上传，需要研究 WKWebView/Android WebView 是否能在
   `onShowFileSelector` 之外保留相对路径；当前结论是做不到，需要明确告知限制，不能伪造。
6. **FTP**：用真实 NAS 再测根目录/子目录/FTPS；当前只做配置备份恢复。
7. **清理**：如确认不再需要 `lib/ios/` 实验代码，可另开分支删除；不要在功能分支顺手删。

---

## 13. 重要约定（不要违反）

- 所有 UI 文案中文；不引入英文占位/假数据。
- 不使用 Mock/Demo 服务、假扫描、假下载进度。
- 不加账号、云同步、遥测。
- 不破坏 Android 现有功能；iOS 当前共用 Material 3。
- 不把认证信息写入 URL/日志/仓库。
- 不在未经用户确认时执行路由器断开等破坏性操作。
- 构建顺序：**iOS CI 先，Android 后**。
- 交付要诚实：没跑过的测试、没生成的截图、没签名的 IPA 都必须明确说明。
