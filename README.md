# ZClient

**ZCode remote control client for Android phones & tablets.** / Android 手机与平板上的 ZCode 远控客户端。

> ⚠️ **非官方项目**：ZClient 与智谱 AI / Z.ai 无任何关系，ZCode 商标与产品归官方所有。使用需自备 ZCode 账号，本项目不提供模型与额度。

## Status

🚧 **早期开发中（WIP）**——协议跑通前没有可用版本。技术方案已定稿：

- **Flutter** 重做 UI/UX，协议层 vendor 自 [ZLinker](https://github.com/opensymph/ZLinker)（MIT）：relay 握手 / 配对证明 / Conversation V4
- **Riverpod** 状态管理；**暗色控制台**默认 + 监控收件箱 IA；平板双栏、手机底栏 3 tab（收件箱 / 设备 / 设置）
- 中英双语（中文优先）；minSdk 26；arm64-v8a + x86_64

## Roadmap

- [x] M0→M1 UI 设计稿（[设计规范 v2.2](docs/design/design-system.md) · [暗色定稿](docs/design/mockups/m1-console.html) · [浅色可选](docs/design/mockups/m1-console-light.html)；[M0 归档](docs/design/mockups/m0-final.html)）
- [ ] M1 协议跑通（扫码配对 + 收发消息）
- [ ] M2 会话核心（流式对话 / 历史导航 / diff 回滚）
- [ ] M3 全功能对齐（任务 / 工作流 / 定时任务 / 小组件 / 统计）
- [ ] M4 打磨发布（GitHub Releases）

## Privacy

无遥测、无广告、无统计 SDK；会话凭证仅存本机；网络请求只发往 ZCode 官方服务与 GitHub Releases 更新检查。

## License

MIT（协议层源文件保留原 MIT 声明）
