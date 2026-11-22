# MD3 对齐改进计划（feature/md3-audit）

> 依据：本机 `android-md3-knowledge` 技能库（快照 2026-11-14 至 2026-11-18，逐页对照 m3.material.io）。
> 项目现状：Flutter 3.50 / Material 3（`useMaterial3: true`），Android、iOS、Windows 共用 `lib/app.dart` → `MainShell`。
> 本文只列差距与执行顺序，不改代码。

## 1. 依据文件

| 主题 | 知识库文件 |
| --- | --- |
| 评审阻断项 | `07-Development-Rules/ui-review-checklist.md` |
| 组件决策规则 | `07-Development-Rules/android-ui-rules.md` |
| 断点与边距 | `01-Foundations/layout.md`、`03-Android-Compose/adaptive-layout.md` |
| 字阶 | `01-Foundations/typography.md` |
| 形状档位 | `05-Design-Tokens/shapes.json` |
| 动效 | `05-Design-Tokens/motion.json` |
| 导航选型 | `02-Components/navigation.md` |
| 组件索引 | `02-Components/README.md` |

## 2. 现状审计（可复现的 grep 证据）

| 项 | 现状 | 证据 |
| --- | --- | --- |
| 页面边距 | 统一 20 | `lib/core/theme/app_spacing.dart` `AppSpacing.page = 20` |
| 分区间距 | 26 | `AppSpacing.sectionGap = 26` |
| 裸字号 | 45 处，含 9.5 / 10 / 10.5 / 11.5 / 12.5 / 13 | `grep -rn "fontSize:" lib` |
| 圆角 | 出现 2 / 5 / 6 / 7 / 10 / 14 / 18 等非档位值 | `grep -rhoE "BorderRadius.circular" lib` |
| 断点 | rail 门槛 700，两列门槛 860，另有「最短边 > 600」 | `lib/core/ui/adaptive_layout.dart` |
| rail 宽 | 平板 256，桌面 80 | 同上 |
| 动效 | 主题切换 240ms `Curves.easeOutCubic` | `lib/app.dart` |
| 触控目标 | 切换服务面板按钮 40×44 | `lib/pages/webview/widgets/service_switcher_sheet.dart:262` |
| 图标按钮密度 | 44 个 IconButton，15 处 `VisualDensity.compact` | `grep -rn "IconButton(" lib` |
| 空态 | 5 个页面用 EmptyState | `grep -rln EmptyState lib/pages` |
| 骨架屏 | 3 处（凭据管理、插件市场、导入页） | `grep -rln ListSkeleton lib` |
| 删除 | 服务删除走确认对话框，无撤销 | `lib/widgets/service_list_tile.dart:32` |

## 3. 差距矩阵

| 规范 | 规范值（来源） | 现状 | 差距 |
| --- | --- | --- | --- |
| 页面边距 | compact 16dp，其余 24dp（layout.md §边距） | 20 | 全档 20，不合档位 |
| 分区间距 | 4/8/12/16/24/32（ui-rules C4） | 26 | 不成体系 |
| 圆角档位 | 4/8/12/16/20/28/32/48/full（shapes.json） | 2/5/6/7/10/14/18 | 需收敛 |
| 断点 | 600 / 840 / 1200 / 1600（layout.md §断点） | 700 / 860 | 数值偏移 |
| 导航 | compact 底栏（3–5 项）；medium 单窗格 rail；expanded 双窗格（navigation.md） | 手机底栏、≥700 rail、≥860 双列 | 基本符合，门槛偏移 |
| SegmentedButton | 官方已标「不再推荐」，改用 connected button group（components/README） | 主题页仍用 SegmentedButton | 组件选择过期 |
| 动效 | spring 物理，spatial 允许过冲（motion.json） | easeOutCubic 240ms | 无弹簧 |
| 触控目标 | ≥48dp（ui-rules F1） | 40×44 | 偏小 |
| 状态 | 加载/空/错误/有内容四态（ui-rules E1） | 空态 5 页，骨架 3 页 | 列表页缺加载态 |
| 删除 | 可逆优先 Snackbar 撤销（ui-rules E4） | 全部确认对话框 | 可优化 |

## 4. 改进计划

### P0 —— 无障碍与状态（阻断项，先做）

1. **触控目标 ≥ 48**：`service_switcher_sheet.dart` 的 40×44 按钮改 48；过滤 15 处 `VisualDensity.compact` 的 IconButton，命中触控框 < 48 的加 `constraints: BoxConstraints(minWidth: 48, minHeight: 48)`。
2. **补加载态**：`services_page`、`devices_page`、`category_page` 首屏改用 `ListSkeleton`，与凭据管理页一致。
3. **200% 字体**：收藏卡 `mainAxisExtent 92`、设备卡固定高改 `minHeight` + 文本 `maxLines` 适配；用 `flutter test` 的 `tester.platformDispatcher.textScaleFactorTestValue` 加回归测试。
4. **删除可撤销**：服务/设备删除改成 Snackbar + 「撤销」（暂存删除对象，5 秒内恢复）；不可逆操作（清空凭据）保留确认。

### P1 —— 设计一致性

5. **边距成档**：`AppSpacing.page` 改为 16（compact）/ 24（其余），由 `AdaptiveLayout` 提供 `pagePadding(context)`；`sectionGap` 26 → 24。
6. **圆角收敛**：2/5/6/7 → 4 或 8；10 → 12；14 → 16；18 → 16 或 20。只保留 4/8/12/16/20/28/full。
7. **字号入阶**：9.5/10/10.5 → labelSmall(11)；11.5/12 → labelMedium/bodySmall(12)；12.5/13 → bodyMedium(14) 或 labelLarge(14)。原则上同屏 ≤ 4 档字阶。
8. **主操作唯一**：每个页面只保留一个 Filled 强调按钮（编辑页「保存」、空态「添加」）。

### P2 —— 响应式

9. **断点对齐**：`sideNavigationMinWidth` 700 → 600；`wideHomeMinWidth` 860 → 840；`tabletMinShortestSide` 条件保留（手机横屏不触发，属产品决策，文档标注）。
10. **rail 宽度**：平板 expanded rail 256（官方 expanded rail 推荐 256）；桌面 compact 80 保留（collapsed rail 官方尺寸为标注图，知识库无法给 dp，标注「团队决策」）。
11. **平板边距**：rail 与内容之间用 24dp spacer（layout.md：medium 起 spacer 24）。

### P3 —— 组件与动效

12. **SegmentedButton 换代**：主题页「自动/浅色/深色」改为 connected button group（Flutter 无官方实现，需自建 `ConnectedButtonGroup`，两次选中态共享描边；工作量约 1 个组件 + 2 处替换）。其他位置（筛选、分段）同步评估。
13. **动效弹簧化**：主题切换、页面转场改用近似 spring 曲线（spatial damping 0.8 / stiffness 380），颜色类过渡保持线性不过冲（motion.json：effects 不允许过冲）。
14. **FAB 与 Filled 按钮尺寸**：按 gestures 与 fab.md 的五档尺寸检查（Expressive 尺寸仍为实验，标注状态）。

## 5. 暂不做 / 需产品决策

- **手机横屏进入 expanded 布局**：M3 把「phone in landscape」归 expanded（840 起），但本产品横屏体验按紧凑处理。保留现状，文档标注为产品决策。
- **connected button group**：Flutter 无官方组件，自建前先确认收益；若收益不足，保留 SegmentedButton 并在文档中记录「官方不再推荐」。
- **自定义取色器**（FlClash 的 + 号）：非 M3 规范项，属产品功能，另排期。

## 6. 执行顺序与验收

1. P0 四项 → `flutter analyze` 干净 + 新增回归测试（大字体重排、触控尺寸）。
2. P1 四项 → 截图对比（浅色/深色/大字号）。
3. P2 三项 → 1024×1366、1280×800、320×568 三个视口测试（沿用 `test/adaptive_layout_test.dart`）。
4. P3 两项 → 组件测试 + 主题切换录屏。

每批单独提交，版本号按约定 +1（patch 与 build 同时 +1）。
