# AI / Infra / RL 示例主题

用户提供的原创技术分析、数学推导、实验和系统实现订阅清单，覆盖 LLM、AI 基础设施和后训练 RL。

- topic.json：一个主题，完整记录 13 个来源的方向、推荐理由、链接与状态。
- subscriptions.opml：仅包含用户报告此前验证通过的 10 个 RSS/Atom 地址，方便后续导入。
- zartbot：保留 RSSHub 候选入口，用户此前请求得到 HTTP 403；默认不启用。
- Costa Huang、Prime Intellect：保留主页与推荐资料，订阅入口为 null；默认不启用。

## 验证来源

这些“已验证”状态来自用户在 2026-11-09 提供的记录，原始验证时间未提供。
本次初始化只检查本地 JSON/OPML 的结构与一致性，**没有重新请求这些订阅端点**。
userReportedStatus 不等于应用运行时检查结果；runtimeVerification 初始为 not_checked。
用户原始说明提到尚未导入本机 Folo；本项目也没有自动导入或访问这些来源。

这是一份版本化示例格式草案，尚无导入器。enabledOnImport 表示用户主动导入时的建议状态，
不授权启动应用时自动抓取。导入后应执行应用自己的状态检查，不能把历史记录当成永久有效。
OPML 只承载通用订阅元数据；主题范围、推荐理由和待确认来源保留在 topic.json。

## 阅读建议

优先关注 Lequn Chen、zartbot、Horace He、Nathan Lambert、Prime Intellect 和 vLLM 的 RL × Infra 内容；
使用 Lilian Weng、苏剑林补充研究脉络与数学原理。候选来源在确认入口后再启用。
部分 Substack 内容可能只有公开摘要，阅读器必须区分摘要与完整正文。

本示例根据用户粘贴的清单生成，没有假定 /tmp/ai-infra-rl-folo.opml 仍然存在。
