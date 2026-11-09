> ⚠️ **已归档，不作为实现基准**（2026-11-09 用户决定采用另一设计路线，见 design-system.md v1.1 与 screens.md）。本文件为并行会话的 v2.2 暗色控制台实验记录；其参考稿为 mockups/m1-console.html 与 m1-console-light.html。

# ZClient 设计规范

> **版本** v2.2 · 2026-11-09 · A+B + quieter + 完整浅色次要主题
> **基调** Termius / Linear 暗色控制台（默认）+ 浅色 quieter 纸面（可选跟系统）+ Cursor Mobile / Hypernova 监控优先 IA
> **参考稿（暗 · 默认）** [mockups/m1-console.html](./mockups/m1-console.html)
> **参考稿（浅 · 可选）** [mockups/m1-console-light.html](./mockups/m1-console-light.html)
> **归档** [mockups/m0-final.html](./mockups/m0-final.html) 为 M0 Material You 历史稿，仅作对照，不再作为实现基准。

---

## 1. 设计决策记录

| 决策 | 结论 | 背景 |
|---|---|---|
| M0 风格 | A · Material You × Apple · 雾蓝浅色 | M0 三套方案评审选定；交付 `m0-final.html` |
| **v2.0 转向** | **A+B · 暗色控制台视觉 + needs-attention 监控 IA** | 用户对 M0 消费级聊天壳不满意；对照 Cursor Mobile / Claude Remote / Hypernova / Termius / Linear / trouve 后锁定 |
| **v2.1 quieter** | 压视觉噪声、去 AI 模板味；保留 A+B 产品锁定 | Impeccable quieter + distill（Operate）+ craft-floor bans |
| 默认主题 | **暗色为默认**；浅色为次要完整主题（可跟随系统） | 工程师远控；暗底让语义色与 diff 说话；浅色 = 安静纸面工具，非 Material You |
| **v2.2 浅色** | 补齐 Light token 全表 + `m1-console-light.html` | 与 Dark 同 IA / quieter 禁令；静态 hex，禁止运行时混色 |
| 主色 | 雾蓝加深版 `#5B8FCE`（品牌种子仍可追溯 `#3D6B9E`） | 保留品牌识别，抬饱和度以适应暗底；`onPrimary` 用深墨 `#0B1220` |
| 材质 | **发丝边分层 · 无 frosted blur · 无重阴影** | 杀掉半透明 chrome；结构靠 elevated surface + hairline |
| 首页 IA | **会话收件箱**（需确认 → 进行中 → 空闲/完成） | 设备卡片首页降级；设备改为顶栏文字切换 / 「设备」tab |
| 手机导航 | 底栏 3 tab：**收件箱 / 设备 / 设置** | 修正 README「抽屉」口径；扫码仅设备页单入口 |
| 批准交互 | **粘性底部 sheet**：允许 / 拒绝 / 始终允许 | 批准不再塞进聊天气泡流当轻卡 |
| Diff | 一级产品面：`+N/−N` 摘要 → 文件列表 → unified diff | 对齐 Cursor Review / trouve |

---

## 1.1 去 AI 味（v2.1 禁令）

Operate 工具界面：中性色承担约 90%；色只用于「需要行动」的状态。层级靠字重与间距，不靠喊色。

| 禁 | 改成 |
|---|---|
| 标题上方 eyebrow / kicker（如「定稿方案 A+B」） | 标题独自成立；外页说明一行 muted 副文即可 |
| 列表/卡左侧 **>1px 彩色边条** | 状态点或极淡底；激活行只用 `primaryMuted` 底 |
| 喊叫徽标（NEEDS YOU、糖果 chip、营销标签） | 小字 muted 或琥珀点 + 「需确认」 |
| 每行堆图标 / 多图标家族 | 少图标；Lucide 一种；默认 muted；标签不必配图标 |
| 层层卡片 / 等大卡网格 | 扁平行列表 + 间距；禁止卡套卡 |
| 玩具感状态栏（装饰 Wi‑Fi/电量抢戏） | 仅时间，或极简 |
| AI 产品营销口吻文案 | 操作员语言：会话名、设备名、命令原文 |
| 琥珀/绿/蓝同时抢戏 | 中性主导；语义色只标行动态 |
| 大圆角 / 处处 pill（18–24） | 行/chip/输入 **8–12**；发送钮可用方圆 7–8 |
| 分组字 `letter-spacing` 戏服、全大写装饰 | 普通 11px muted 中文分组，或干脆不要 |

签名动作（保留一处）：**待确认时的粘性批准 sheet**（允许为主按钮）。其余时刻输入栏退居次要。

---

## 2. 色彩系统

### 2.1 种子与强调色

- **品牌种子（可追溯）**：雾蓝 Misty `#3D6B9E`
- **暗色默认 Primary**：`#5B8FCE`（亦接受 `#4A8BC7`）；`onPrimary` `#0B1220`
- **浅色 Primary**：`#3A6EA5`（亦可种子 `#3D6B9E`）；`onPrimary` `#FFFFFF`

### 2.2 Dark 模式 Token（**设计稿基准 / 默认主题**）

| Token | 值 | 用途 |
|---|---|---|
| `background` | `#0D1117` | 页面底 |
| `rail` | `#0B0F14` | 平板侧栏（比内容区更暗，导航退后） |
| `elevated` | `#161B22` | 底栏、sheet、输入域 |
| `surface` | `#1C2128` | 代码块 |
| `surfaceHover` | `#21262D` | 行悬停 / 按压 |
| `text` | `#E6EDF3` | 正文、标题 |
| `muted` | `#8B949E` | 副文、工具名 |
| `faint` | `#8B949E`（与 muted 同阶；弱层级靠字重/间距，不靠再降对比） | 时间、分组、弱提示 |
| `primary` | `#5B8FCE` | 主操作、激活 |
| `onPrimary` | `#0B1220` | primary 填充上的内容 |
| `primaryMuted` | `rgba(91,143,206,.12)` | 激活行底、用户气泡（更淡） |
| `border` | `rgba(240,246,252,.10)` | hairline |
| `borderStrong` | `rgba(240,246,252,.16)` | sheet 顶缘 |
| `success` | `#3FB950` | 在线、diff 新增 |
| `danger` | `#F85149` | diff 删除、回滚 |
| `warning` | `#D29922` | 需确认状态点 / 小字 |
| `diffAddBg / Fg` | `rgba(63,185,80,.12)` / `#3FB950` | + 行 |
| `diffDelBg / Fg` | `rgba(248,81,73,.12)` / `#F85149` | − 行 |
| 代码 kw / fn / str / base | `#79C0FF` / `#D2A8FF` / `#A5D6FF` / `#E6EDF3` | 语法高亮 |

实现：全部预算为静态 hex / rgba 进 theme，**禁止运行时 color-mix / 动态混色**。

### 2.3 Light 模式 Token（次要完整主题 · 可跟随系统）

浅色是 **Dark 的对等主题**（同 IA、同 quieter 禁令），**不是默认**。场景：强光室外 / 用户跟系统浅色。气质：冷静纸面工具（暖/冷灰纸），**禁止** Material You 马卡龙 / 大圆角白卡 / blur。

主色用品牌种子略提的 `#3A6EA5`（亦可 `#3D6B9E`）；`onPrimary` 为白。对照稿：[m1-console-light.html](./mockups/m1-console-light.html)。

| Token | 值 | 用途 |
|---|---|---|
| `background` | `#F4F5F7` | 页面底（纸面） |
| `rail` | `#ECEEF1` | 平板侧栏（比内容区略冷/略深，导航退后） |
| `elevated` | `#FFFFFF` | 底栏、sheet、输入域 |
| `surface` | `#EEF0F3` | 代码块 |
| `surfaceHover` | `#E6E8EC` | 行悬停 / 按压 |
| `text` | `#1B1F24` | 正文、标题 |
| `muted` | `#5C6570` | 副文、工具名 |
| `faint` | `#7A8490` | 时间、分组、弱提示 |
| `primary` | `#3A6EA5` | 主操作、激活（亦接受种子 `#3D6B9E`） |
| `onPrimary` | `#FFFFFF` | primary 填充上的内容 |
| `primaryMuted` | `rgba(58,110,165,.10)` | 激活行底、用户气泡 |
| `border` | `#D8DCE2` | hairline |
| `borderStrong` | `#C9CED6` | sheet 顶缘 |
| `success` | `#1A7F37` | 在线、diff 新增 |
| `danger` | `#CF222E` | diff 删除、回滚 |
| `warning` | `#9A6700` | 需确认状态点 / 小字 |
| `diffAddBg / Fg` | `rgba(26,127,55,.10)` / `#1A7F37` | + 行 |
| `diffDelBg / Fg` | `rgba(207,34,46,.10)` / `#CF222E` | − 行 |
| 代码 kw / fn / str / base | `#0550AE` / `#8250DF` / `#0A3069` / `#1B1F24` | 浅底语法高亮 |

### 2.4 动态取色

Android 12+ 可跟随壁纸（`dynamic_color`）；**默认关闭**，品牌/控制台色为基线。设置：「品牌色 / 跟随壁纸」。

---

## 3. 排版与尺度

**字体**：系统栈——PingFang SC / 平台中文 + Roboto；代码 SF Mono / Roboto Mono / Menlo。不打包字体。

| 角色 | 字号 | 字重 | 字距 | 行高 | 场景 |
|---|---|---|---|---|---|
| Display | 17–18sp | 600 | −0.02em | 1.2 | 页标题「收件箱」 |
| Title | 13–14sp | 600 | −0.01em | 1.25 | 会话名、sheet 标题 |
| Body | **12.5–13sp** | 400–500 | 0 | 1.45 | 消息、列表主行 |
| Caption | **11sp** | 400 | 0 | 1.35 | 设备名、时间、副文 |
| Micro | **≥11sp** | 400–500 | 0 | 1.2 | 分组、状态小字、tab 标签（无 letter-spacing 戏服） |
| Code | 11–12sp | 400 | 0 | 1.55 | 命令、diff、代码块 |

### 3.1 Spacing / Radius / Icon

| 尺度 | 值 |
|---|---|
| 页边距 | 14–16dp |
| 列表行垂直 pad | 8–10dp |
| 区块间隙 | 0–8 / 12dp（扁平行，少卡内边距） |
| **圆角 · 行/输入/tool** | **6–8dp** |
| **圆角 · sheet 无顶大圆** | 顶缘直角 + hairline（v2.1：去掉 16 顶圆「糖果感」） |
| 发送钮 | 方圆 **7–8dp**（非圆形 pill） |
| 触控目标 | ≥ 44dp |
| 图标 | 15–17dp；行内 chevron 15；默认 stroke muted |
| 状态点 | 5–6dp |

杀掉：20–24dp 大白气泡圆角、消费级大卡片阴影、处处 pill。

---

## 4. 信息架构（监控优先）

### 4.1 手机（< 600dp）

- **底栏 3 tab**：`收件箱`（会话） / `设备` / `设置`
- **收件箱 = 首页**：分组排序 —— **需确认 → 进行中 → 空闲/完成**
- 设备切换：收件箱顶栏 **文字 + 绿点**（非 pill chip）
- 扫码添加：**仅设备页**一个入口（顶栏文字钮；禁止双入口）
- 会话详情：消息流 + 可展开 tool；有待确认时 **粘性底部批准 sheet** 为唯一主操作
- Diff：从 `+N/−N` 摘要进入；文件列表 → unified diff；回滚 = danger 文本

### 4.2 平板 / 横屏（≥ 600dp）

- **双栏**：左轨 ~268dp = 设备组 + **会话收件箱** + 底设置；轨底 **比内容区更暗**（Linear：导航退后）
- 右栏与手机共用组件；宽屏 ≥ 840dp 预留第三栏（diff/详情），本期不做

### 4.3 断点

compact < 600dp / medium ≥ 600dp / wide ≥ 840dp（预留）。

---

## 5. 材质与层级

- **禁止** `backdrop-filter` / frosted blur。
- 分层：`rail` / `background` → `elevated` → `surface`；交界用 **1px hairline**，不用重阴影。
- Sheet：**无大投影**；靠顶缘 `borderStrong` 分层即可。
- Chrome（顶栏、底栏、输入）：实底 + hairline，内容不从下方「穿过」。

---

## 6. 组件规范（对照 m1-console / m1-console-light v2.2）

| # | 组件 | 关键规格 |
|---|---|---|
| 1 | **收件箱行** | 扁平；6dp 状态点；主行 12.5–13sp 500；副行命令/摘要 faint；右 `+N/−N` 或时间；**无左边条、无喊叫徽标** |
| 2 | **需确认提示** | 小字「需确认」warning **或** 仅琥珀点；不要 chip 底 |
| 3 | 设备切换（顶栏） | 文字 + 5dp 绿点；非 pill |
| 4 | 设备列表行 | 分隔线列表；无 elevated 边框卡；在线绿点 |
| 5 | 用户气泡 | 右对齐、`primaryMuted`、圆角 **10/10/3/10**、max ~78% |
| 6 | Agent 块 | 左对齐、无大卡；正文贴 background |
| 7 | **Tool 卡** | 透明底 + hairline r8；默认折叠；等宽工具名；展开才见命令 |
| 8 | Diff 摘要 | hairline r8；文件名等宽；`+N/−N`；可点进 Diff |
| 9 | **批准 Sheet** | sticky、elevated、顶 hairline；标题动作名 + 等宽命令；三键 **允许（fill）/ 拒绝 / 始终允许**（次要无色边） |
| 10 | 输入栏 | elevated 域 r8；发送 **方圆 7–8** primary |
| 11 | 底栏 | elevated + 顶 hairline；3 tab；激活 primary |
| 12 | 流式状态 | 5dp primary 点 + faint 文 + 细 caret |
| 13 | Diff 视图 | hairline；行号 faint；+/− 语义底；回滚 = danger 文本 |
| 14 | 状态点 | 需确认 warning / 进行中 primary / 在线 success / 完成或离线 faint |

---

## 7. 动效与手感

- **冷静、无弹跳**：按压缩放 0.97，100–150ms ease-out；默认 spring `damping 1.0`。
- 仅功能性运动；无装饰入场编排。
- 「减弱动态效果」→ 全部 cross-fade。
- 多模态：批准 / 拒绝 / 配对成功 → 视觉 + `HapticFeedback.lightImpact` 同帧。

---

## 8. 无障碍

- 对比度：暗 `#E6EDF3` on `#0D1117` ≈ 15:1；浅 `#1B1F24` on `#F4F5F7` ≈ 14:1；primary 作大面积字时需加粗或配 onPrimary 底；warning 不单靠色（配「需确认」文案或点+文）。
- 触控 ≥ 44dp。
- 动态字体 sp + 弹性布局，200% 不截断关键操作。
- 双编码：diff 颜色 + `+/−`；状态 = 文字或点 + 色。

---

## 9. Flutter 落地映射

| 设计 | Flutter |
|---|---|
| 暗色默认 token | `ThemeData(brightness: dark, …)`；primary `0xFF5B8FCE`；集中 `AppColors` |
| 浅色可选（跟系统） | 独立 `lightColorScheme`；token 见 §2.3；默认仍 dark |
| 材质 | **无** `BackdropFilter`；hairline `Border` |
| 收件箱 | `CustomScrollView` + section headers；无左边条装饰 |
| 批准 sheet | 会话页内嵌 sticky `SafeArea` 底栏 |
| Tool 展开 | `ExpansionTile` / `AnimatedCrossFade`；默认折叠 |
| 双栏 | `LayoutBuilder` ≥600 → ~268dp 更深色 rail |
| 按压 | `AnimatedScale` + onTapDown |
| 动态取色 | `dynamic_color`，默认关 |

---

## 10. 状态矩阵（M1 必覆盖）

| 区域 | 状态 |
|---|---|
| 收件箱 | 空（引导配对）/ 仅完成 / 有进行中 / 有需确认 |
| 会话 | 连接中 / 流式输出 / 待确认 / 失败可重试 / 已完成 |
| 设备 | 在线 / 离线 / 配对中 / 相机权限拒 |
| 批准 sheet | 空闲 / 提交中 loading / 失败 |
| Diff | 无变更 / 单文件 / 多文件 / 回滚确认 |

---

## 11. 版本与待补

- **v1.0（已归档）**：浅色 Material You × Apple；`m0-final.html`
- **v2.0**：暗色控制台默认 + 监控收件箱 IA + `m1-console.html`
- **v2.1**：quieter/distill 去 AI 味；禁 eyebrow / 厚左边条 / 喊叫徽标 / 卡套卡；中性主导；批准 sheet 为唯一签名动作
- **v2.2（本稿）**：浅色 quieter 完整 token + `m1-console-light.html`；暗色仍为默认；浅色可跟随系统
- **待补**：扫码配对全流程；通知动作；小组件；wide 三栏；设置内主题切换 UI
