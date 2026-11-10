# dsh-Go 源码级视觉规格（逆向提取）

> 2026-11-10 从 ccch1mneyyy/dsh-Go `app/lib/ui/` 源码（AGPL，仅设计复刻）
> 提取的精确实现参数。此文件是 ZClient UI 的最高优先级事实源，
> 优先级高于 dsh-visual-spec.md（截图估测）。

## 修改清单（对照 ZClient 现状）

### A. 壳与抽屉
1. 抽屉宽度 280→320 + safeLeft, min(屏宽-56)
2. 窄屏弃 Scaffold.drawer → 单 AnimationController + Transform.translate + RepaintBoundary
3. 宽屏阈值 840dp（非 600）
4. 底层页面随抽屉位移 0.14（仅平移）

### B. 抽屉内部
5. 品牌行 padding LTRB(20,14,10,10)，contentEdge=10 统一
6. 新会话：36 高 Stadium 实心 pill（非全宽），icon 20 + labelLarge
7. 筛选 chips：无边框，底 onSurface@5%（dark 白@7%），选中 onSurface（墨色），fontSize 13
8. 身份栏 padding LTRB(10,9,10,13)，头像 36 圆 icon 19，两键 44 圆 icon 22 间距 8
9. 会话行高 44，选中底 primary@0.09(light)/0.18(dark)
10. 列表上下边缘 ShaderMask 渐隐（顶 10dp / 底 16dp）

### C. 输入卡
11. 圆角 28，外 padding LTRB(6,6,6,6)（无+键时左18），单行高 48
12. 键尺寸 36，间隙 6，行内 8
13. 文字 15/1.45，hint 同字号 textTertiary
14. 发送键 36 圆：active=primary / 禁用=onSurface@12%底+@38%前景；icon send 20/stop 18；按压缩放 0.9
15. maxLines 自适应 (可用高*0.4/行高).clamp(2,6)

### D. 顶栏
16. 栏高 56，胶囊 minHeight 44 左padding 16 Stadium
17. 标题 15/1.3，状态行 11/1.25 + dot 6 + gap 5 + tertiary
18. TopFade 高 top+56+12，opacity=(offset/24).clamp(0,1)
19. 收缩阶梯（chip→标题→chip缩→端盖→穿底）

### E. Pressable
20. 滚动容器延迟 AppMotion.press 后显示；spring 松开；touchSlop 取消

### F. 弹层
21. 顶圆角 28 gutter 20；分组卡 radius-lg 超椭圆，组内 2px 无分隔；拖把 36×4@35%；fling 700px/s

### G. tokens
22. 补：radius 28 / keySize 36 / barHeight 56 / roundKey 44+icon22 / contentEdge 10 / composerFont 15/1.45 / 选中 alpha 0.09·0.18

## 关键设计模式
- **一实多虚**：全抽屉只有"新会话"是实心主色
- **胶囊端盖同心**：键36+间隙6=48高，圆角28=同心
- **BackdropGroup**：一行玻璃件共享一次背景采样
- **无 AppBar 板块**：返回键是浮动玻璃圆钮+大字页头
- **程序化对比度**：FeatureTile 四色阶由 primary lerp 而来+对比度检验
- **SmoothSize**：高度/宽度变化滑动而非跳变
