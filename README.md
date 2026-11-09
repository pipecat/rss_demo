# Topic Reader Demo

围绕 Topic 的原生阅读器，优先做好原文排版，支持用户自带本地或远程 AI。

**当前状态：已实现可本地运行的 macOS「LLM」阅读 Demo。**

## 打开与构建

在 Finder 打开 `dist/Topic Reader.app`，或在仓库目录运行：

```sh
open "dist/Topic Reader.app"
```

重新构建与离线检查：

```sh
bash scripts/build-app.sh
.build/debug/ReaderChecks
```

使用 Swift Package Manager，依赖固定版本并记录在 `Package.resolved`。本机 Command Line Tools 可以完成当前构建，无需先安装完整 Xcode。脚本生成本机架构的 Debug App，附带资源、许可证与临时签名；不是经过公证的正式分发版本。声明最低 macOS 14，当前只在本机 Apple Silicon / macOS 26.5.1 验证。

## 已实现

- SwiftUI 三栏原生界面：主题与来源、文章列表、隔离的 WebKit 阅读页。
- LLM Demo 关联已有示例中的 Lequn Chen、Horace He、Interconnects、Lilian Weng、苏剑林与 vLLM 六个来源。
- 用户主动导入刷新；不在启动时联网。显示各来源最后成功时间和错误，失败保留缓存。
- 搜索标题和摘要、来源筛选、未读筛选、收藏、字号调整、系统亮暗模式。
- FeedKit 解析 RSS 2.0 / Atom；Readability + JSDOMParser 在无原生桥的 JavaScriptCore 内提取正文；SwiftSoup 独立清理 HTML。
- 原始订阅内容、抓取页面与清理正文分开保存；订阅正文和提取正文都不保证完整。
- 默认不加载远程图片、字体、脚本、iframe 或媒体，保留图片说明和占位。支持原生 MathML；TeX 保留来源文本，未接入公式脚本。
- JSON 原子写入本地缓存，保留已读、收藏和提取结果；来源管理页可导出不含文章的主题 JSON、清除缓存。
- 可配置仅指向 `127.0.0.1` 的 HTTP / SOCKS5 代理端口；留空沿用系统网络设置，不修改系统代理。

快捷键：⌘R 刷新、⌘D 收藏、⌘J/⌘K 下一篇/上一篇、⌘O 打开原文。阅读页支持文本选择、复制和链接键盘导航；VoiceOver 全流程仍待人工验收。

文章仅保存在 `~/Library/Application Support/TopicReader/library.json`，不打入 App 或提交仓库。代理协议和端口保存在应用偏好设置中，不包含凭据。

## 当前边界

Demo 尚未实现任意来源编辑、通用 OPML/主题文件导入、图片下载、AI、自动后台刷新、SQLite、迁移框架或跨设备同步。网络请求只允许 Demo 中配置的 HTTPS 主机，跨主机跳转仍重新校验；其他来源需要后续扩展策略。

来源入口的历史验证仍保留在 `example/ai-infra-rl/`，实际刷新状态以 App 本地缓存为准。首次生成本机 Demo 时按用户指令主动抓取；以后打开不自动刷新。

## 已确定方向

- macOS 首发：Swift + SwiftUI；WebKit 作为隔离的文章渲染适配层。
- 多端模块化：Apple 平台共享 Swift 核心；其他平台通过数据格式与模块契约扩展。
- 无业务服务器：设备直接访问订阅源及用户配置的模型 API，内容本地存储。
- 不配置模型也能阅读。远程模型会收到用户主动提交的内容；不经过本项目中转服务。
- 文章提取、清理和排版独立于 AI，保留原文结构，清楚区分全文与摘要。

## 目录

```text
rss_demo/
├── AGENTS.md                  # 后续开发必须遵循的约定
├── README.md
├── Package.swift              # target 边界与固定版本依赖
├── Package.resolved           # 依赖解析记录
├── Apps/macOS/                # 原生窗口、三栏 UI 与 WebKit 容器
├── Packages/                  # Domain、Application、Adapters
├── Tests/ReaderChecks/        # 离线验证入口
├── scripts/                   # 构建、图标生成
├── THIRD_PARTY_NOTICES.md      # 第三方许可
├── init/
│   ├── ARCHITECTURE.md         # 模块边界、数据流、迭代顺序
│   └── ENVIRONMENT.md          # 本机环境检查与后续准备
└── example/
    └── ai-infra-rl/
        ├── README.md          # 示例说明与验证来源
        ├── topic.json         # 一个 Topic、13 个来源及元数据
        └── subscriptions.opml # 10 个用户此前验证过的订阅地址
```

新增实现目录：`Apps/macOS/`、`Packages/ReaderDomain/`、`Packages/ReaderApplication/`、`Packages/ReaderAdapters/`、`Tests/ReaderChecks/` 和 `scripts/`。

23 项离线检查覆盖 RSS/Atom、实体声明拦截、HTML/URL 安全、结构保留、去重、缓存与真实 Readability 库执行。视觉验收使用本地合成文章，截图输出到忽略目录 `artifacts/`。

第三方依赖及许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。NetNewsWire 仅作为结构与交互参考，未复制其代码或素材；本项目自身的开源许可证尚待确定。没有接入真实模型。

从 [开发约定](AGENTS.md)、[架构设计](init/ARCHITECTURE.md) 和 [环境说明](init/ENVIRONMENT.md) 开始。
