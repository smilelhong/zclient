# ZClient ↔ zic 功能对齐清单

> 2026-11-09 用户定调：**功能先对齐 zic（稳态），UI 对齐 dsh-Go（design-system v1.1）**。
> 本清单以 zic@1.0.21 源码为基准逐模块盘点差距；P0 = 直接造成"zic 没遇过、我们遇到了"的体验问题。

## P0 — 登录与连接稳态（这次 401 事件的全部教训）

| # | zic 的做法 | ZClient 现状 | 动作 |
|---|---|---|---|
| 1 | 登录页 800ms 轮询 + `captureStabilityDelay` 2s 稳定窗 + `jwtFromStorageProbe` 严格三段式校验 + **必须手动点「完成」才落库**（防止半登录态被收割） | 轮询 900ms，手动抓取有了，但**没有稳定窗**、没有形状外的可用性验证 | 移植稳定窗；收割后立即**试铸 relay token 验证**（mint 非 200 → 当场提示"此登录不可用，请换 BigModel 入口重登"，不落库） |
| 2 | 登录方法 chips（bigmodel 默认/zai/auto），选择持久化；auto-click 只点选中入口 | 无 chips，auto-click 写死 BigModel | 补方法 chips + 持久化（auto-click 已有） |
| 3 | WebView 导航时 `saveCookies`（同域 cookie 持久化，恢复登录态） | 只存 JWT | 接入 saveCookies |
| 4 | `DeviceStatus` 状态机（disconnected/connecting/connected/error/degraded）+ `retryBackoff` 30s 自动重试 + `_maybeScheduleRetry` | relay 层 15s 固定重连，App 层无状态机、无重试、错误只有一条横幅 | App 层补状态机：401/auth-required → 提示重登并跳登录页；网络类 → 自动退避重试 |
| 5 | auth-required/relay-unavailable 等 RelayFailure 分类直达 UI 动作 | 部分翻译了文案，无对应动作 | 错误分类 → 用户动作映射（重登/重试/去设置） |

## P1 — 会话与多设备体验

| # | zic | ZClient | 动作 |
|---|---|---|---|
| 6 | DeviceSession 2350 行：多设备并发、每设备独立会话、断线恢复、workspace 切换、任务列表实时 phase | 单设备单会话；切换设备=断开重连 | 迁移到 per-device 会话模型（至少：切设备不丢 UI 状态、每设备记住自己的会话） |
| 7 | 会话操作全集：rename/pin/archive/unread/delete/stop/compact | 无 | 会话长按菜单 + stop（聊天页加停止按钮） |
| 8 | 发送队列（heldQueue/queued items/editQueue） | 直接 sendText | 排队至少展示"发送中"状态 |
| 9 | 附件/图片发送（attachmentPut） | 无 | M3 批3+ |
| 10 | 交互卡完整集（plan approval/hook review/elicit 多选题） | options/信任 两种 | 补 plan approval 卡 |

## P2 — 通知/更新/自动化（M3 批3 计划内）

- 通知：完成/待确认系统通知（flutter_local_notifications）+ 免打扰规则（notify_rules.dart 113 行可参考）
- 更新：GitHub Releases 检查 + 跳浏览器（update_service.dart）
- 定时任务：automations + off_peak 三合一页（vendor 层已备）
- 小组件：home_widget 设备状态

## UI 侧（对齐 dsh-Go，按 design-system v1.1 继续推进）

- 已完成：theme 地基/设备页/会话页换皮（验收 8/10）
- 待做：聊天屏专项抛光（元信息行等宽/交付卡细化）、宽屏 readingWidth 720 居中、设置枢纽页概览卡、暗色全量核查、Pressable 包裹全部可点元素、空态全套

## 验收口径

- **功能**：用户日常路径（登录/配对/收发/切换/断线恢复）与 zic 同等稳定——"zic 从没遇到的问题"清零
- **UI**：对照 docs/design/design-system.md v1.1 量化规范逐屏过
