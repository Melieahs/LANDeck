# LANDeck 原生模块插件接口

LANDeck 的「原生模块」用于给某个服务提供 Flutter 原生页面，同时保留同一条服务记录的
WebView 模式。模块通过服务编辑页里的「原生模块」显式关联，不会按名称或地址自动绑定。

## 为什么是声明式插件

Flutter 的 Android/iOS 安装包是 AOT 编译的，不能在运行时加载任意 Dart 代码；
动态下载并执行原生二进制也不适合 iOS，并会带来严重的安全问题。因此当前版本只支持
**声明式插件**：

- 插件只能声明 HTTP 请求和结果展示方式；
- 不执行 JavaScript、Dart、Swift/Kotlin 或任意脚本；
- 请求只能发往被关联服务的同一协议、主机和端口；
- 使用 HTTP Basic 认证时，凭据由 LANDeck 已有的加密存储按服务保存；
- 不提供文件访问、系统命令、任意 URL、Cookie 注入等能力。

这使同一个插件可以同时运行在 Android 和 iOS 上，并且导入前可以完整审查。

## 包格式

支持两种文件：

1. 单个 `.json` 清单；
2. `.zip` 包，根目录（或任意一级子目录）包含 `plugin.json`。当前版本不会读取
   其他资源，图标使用内置图标名。

清单最大 128 KB，整个包最大 512 KB。

## 清单示例

```json
{
  "schemaVersion": 1,
  "id": "plugin.http-title",
  "name": "网页标题",
  "version": "1.0.0",
  "description": "读取服务首页的标题，只读。",
  "author": "LANDeck",
  "permissions": ["http"],
  "match": {
    "hostPatterns": ["192.168.1.*"],
    "ports": [80, 8080]
  },
  "basicAuth": false,
  "status": {
    "method": "GET",
    "path": "/",
    "fields": [
      {
        "label": "标题",
        "pattern": "<title[^>]*>(.*?)</title>",
        "group": 1
      }
    ]
  },
  "actions": []
}
```

## 字段

### 顶层

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `schemaVersion` | 否 | 当前固定为 `1` |
| `id` | 是 | 必须以 `plugin.` 开头，小写字母/数字/`.`/`_`/`-`，导入后不可与内置模块冲突 |
| `name` | 是 | 显示名称 |
| `version` | 是 | 插件版本，展示用 |
| `description` | 是 | 导入确认与列表中的说明 |
| `author` / `homepage` | 否 | 来源信息 |
| `permissions` | 否 | 当前只允许 `["http"]` |
| `match` | 否 | 兼容性限制；省略表示所有有 URL 的服务都可手动关联 |
| `basicAuth` | 否 | 为 `true` 时显示登录卡，使用安全存储保存凭据 |
| `status` | 否 | 状态读取请求与字段 |
| `actions` | 否 | 最多 8 个操作 |

### match

```json
"match": {
  "hostPatterns": ["192.168.1.*", "nas.*"],
  "ports": [80, 5000]
}
```

`hostPatterns` 支持 `*` 和 `?`，不区分大小写；`ports` 匹配服务 URL 的端口。
两个条件同时存在时需要同时满足。兼容性只决定“能否关联”，不会自动关联。

### status

```json
"status": {
  "method": "GET",
  "path": "/api/status",
  "query": {"simple": "1"},
  "fields": [
    {"label": "状态", "path": "state", "map": {"up": "在线", "down": "离线"}},
    {"label": "WAN IP", "path": "wan.ip"},
    {"label": "版本", "pattern": "version=([0-9.]+)", "group": 1}
  ]
}
```

- `path` 必须以 `/` 开头，不能是完整 URL。
- 响应按 JSON 解析；`path` 使用点号路径（如 `wan.ip`）。
- 如果不是 JSON，仍可用 `pattern` 正则从原始文本提取，`group` 默认为 1。
- `map` 把原始值映射为可读文本。
- 最多 16 个字段。

### actions

```json
"actions": [
  {
    "id": "reconnect",
    "label": "重连 WAN",
    "icon": "refresh",
    "description": "重新建立 WAN 连接",
    "confirmText": "重连会短暂断网，继续？",
    "refreshDelaySeconds": 5,
    "request": {
      "method": "POST",
      "path": "/api/wan/reconnect",
      "form": {"action": "connect"}
    }
  }
]
```

- `method` 支持 GET/POST/PUT/PATCH/DELETE。
- `form` 会以 `application/x-www-form-urlencoded` 发送；`json` 会以 JSON 发送。
- `query` 追加查询参数。
- `headers` 可附加普通请求头；`Authorization` 由 LANDeck 根据登录凭据设置。
- `confirmText` 非空时显示确认框；为空则直接执行（示例插件 Padavan 也不做二次确认）。
- `refreshDelaySeconds` 在操作成功后等待并刷新状态，范围 0–120。
- `icon` 支持 `refresh`、`power`、`wifi`、`settings`、`restart`、`download`、
  `upload`、`play`、`stop`，其他值使用通用图标。

### basicAuth

启用后，模块页面先显示登录卡。用户名/密码只在用户勾选「记住登录信息」时写入
Android Keystore / iOS Keychain，绑定 `serviceId + host:port + plugin:<id>`；
请求只会在当前服务地址上携带 Basic Authorization。

## 安装与卸载

三种安装方式：

1. **发现页插件源**：打开「发现」→「模块插件」，从 LANDeck 仓库读取插件索引，点
   「安装」后先下载清单，展示名称、版本、作者、状态请求和操作列表，确认后才写入。
2. 设置 → 原生模块 → 右上角 `+` / 「导入 .json / .zip 插件」，导入本地文件。
3. 命令行/自动化场景可直接把清单放到应用支持目录的 `native_modules/*.json`。

导入后到服务编辑页 →「原生模块」选择该模块，再选择「默认打开方式」。

卸载会删除插件清单；已关联服务自动回退为 Web 模式，已保存的密码不会删除。

## 插件源（发现页）

插件源是仓库里的一个 JSON 索引，默认地址：

```
https://raw.githubusercontent.com/Melieahs/LANDeck/main/examples/native-modules/index.json
```

格式：

```json
{
  "schemaVersion": 1,
  "plugins": [
    {
      "id": "plugin.padavan-wan",
      "name": "Padavan 路由器",
      "version": "1.0.0",
      "description": "读取 WAN 状态并控制连接。",
      "author": "LANDeck",
      "path": "padavan-wan/plugin.json"
    }
  ]
}
```

- `path` 必须相对于索引地址，只能是 `.json`，不能是绝对路径、URL 或包含 `..`；
- `id` 必须以 `plugin.` 开头，且索引内不能重复；
- 索引最大 128 KB，单个清单最大 128 KB；HTTP(S) 之外的协议一律拒绝；
- 下载的清单仍走本地导入相同的校验流程，确认框里会列出全部请求；
- 索引只在打开发现页时读取，可手动刷新；缓存写入与应用内导入的插件相同。

当前只收录 `examples/native-modules/` 下的插件。未合入默认分支的插件在发现页不可见。

## 版本与兼容

- 当前只实现 `schemaVersion: 1`。
- 不支持的字段会被忽略；非法 id、绝对 URL、未知权限、超限数量会拒绝导入。
- 插件不做代码签名；只导入你信任的来源。声明式插件虽然不能执行代码，但仍可向关联
  服务发送修改类请求，导入前请审查 `actions`。
- 暂不支持第三方插件源、签名校验、脚本/自定义 UI 和版本更新提示。
