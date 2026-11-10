# 开发环境

检查日期：2026-11-09 至 2026-11-10（Asia/Shanghai）。

## 当前本机配置与验证

2026-11-10 完成工具链升级后，在当前工作区重新检查，结果如下。后文保留的旧环境和联网记录不代表本轮实测。

| 项目 | 本轮结果 |
| --- | --- |
| 系统 | macOS 26.3.1（25D2128），Apple Silicon / arm64 |
| Xcode | 26.6（17F113），已安装于 /Applications/Xcode-26.6.app |
| 活动开发目录 | /Applications/Xcode-26.6.app/Contents/Developer |
| Swift | Apple Swift 6.3.3，swiftlang-6.3.3.1.3 |
| macOS SDK | 26.5 |
| 首次初始化 | 用户已登记许可并完成初始化，`xcodebuild -checkFirstLaunchStatus` 返回 0 |
| 调试与语言服务 | Xcode 自带 LLDB、SourceKit-LSP 可定位；未单独验证调试会话 |

项目及锁定的 FeedKit 10.10.2、SwiftSoup 2.14.3 均声明 Swift tools 6.0。本轮用 Xcode 26.6 / Swift 6.3.3 完成 Debug 构建、App 打包与 ad-hoc 签名验证；23 项离线检查全部通过，无需修改业务代码。应用使用合成文章启动，SwiftUI 三栏和 WebKit 阅读页截图已检查，产物在 `artifacts/xcode-26.6-light/`（不提交）。本轮没有刷新真实订阅或调用模型，也未验证 SwiftUI 预览、模拟器或正式分发签名。

系统默认工具链已切换至新版。此前 Xcode 16.0 / Swift 6.0 也通过了相同的构建和离线检查，其合成文章截图保留在 `artifacts/environment-check/`。最低部署版本仍由 `Package.swift` 和 `Apps/Info.plist` 声明为 macOS 14，不代表已经在该系统实测。

### 升级记录（2026-11-10 完成）

用户随后要求升级到当前系统支持的最新稳定开发环境。根据 [Apple 官方兼容表](https://developer.apple.com/xcode/system-requirements)，当前 macOS 26.3.1 的目标为 Xcode 26.6 / Swift 6.3；Xcode 27.2 要求 macOS 26.6 或更新系统，暂不涉及系统升级与重启。

- 独立的 Command Line Tools 26.6 安装尝试未成功，包收据仍为 CLTools 16.0。当前实际使用完整 Xcode 26.6 自带的编译器和 SDK，开发此项目不依赖旧的独立 CLTools。
- 用户登录 [Apple 官方下载入口](https://developer.apple.com/download/all/?q=Xcode%2026.6) 后，已下载 Apple Silicon 安装包并安装至 `/Applications/Xcode-26.6.app`，版本 26.6（17F113）。旧版 `/Applications/Xcode.app` 保留。`codesign --verify --deep --strict` 通过，Gatekeeper 返回 `accepted / source=Apple System`。
- 下载时使用用户同意的 Chrome Apple 站点临时代理；完成后已将该站点恢复为直接连接。安装包保留在 `~/Downloads/Xcode_26.6_Apple_silicon.xip`。
- 用户已在终端完成许可登记、首次初始化和 `xcode-select --switch`。已核实无 `DEVELOPER_DIR` 覆盖时，默认 `xcodebuild` 为 26.6、Swift 为 6.3.3、macOS SDK 为 26.5，首次初始化检查通过。

### 日常开发命令

日常开发优先使用 CLI，完整 Xcode 提供编译器、SDK 与调试工具，无需常开 IDE。在仓库目录执行：

```sh
bash scripts/build-app.sh
.build/debug/ReaderChecks
open "dist/Topic Reader.app"
```

需要 IDE 调试或 SwiftUI 预览时，才使用 `open -a /Applications/Xcode-26.6.app Package.swift`。

首次构建需要联网获取锁定依赖；依赖缓存就绪后，离线检查无需联网。构建产物保存在忽略目录 `.build/` 和 `dist/`。

本轮 Git 全局 SOCKS5 代理连接停滞，而已配置的 `127.0.0.1:7890` HTTP 代理可用。通过以下仅作用于当前命令的覆盖完成下载；它不修改全局 Git 或系统代理。此端口是本机实测值，其他机器按自己的配置调整，无需代理时使用上面的普通构建命令：

```sh
GIT_CONFIG_COUNT=2 \
GIT_CONFIG_KEY_0=http.proxy GIT_CONFIG_VALUE_0=http://127.0.0.1:7890 \
GIT_CONFIG_KEY_1=https.proxy GIT_CONFIG_VALUE_1=http://127.0.0.1:7890 \
bash scripts/build-app.sh
```

## 全文预抓取验证（2026-11-10）

工具链升级后的功能迭代已通过 Debug App 构建、临时签名校验和 40 项离线检查。新增检查覆盖刷新自动提取、缓存复用、旧摘要补抓、逐篇发布、失败回退与恢复、空缓存保护、取消、持久化和全文渲染。

使用 `--visual-check --prefetched` 展示短订阅摘要与独立提取的长篇合成正文，检查亮色及暗色窄窗口下的正文、代码、表格、MathML、图片占位与脚注。截图保存在 `artifacts/prefetch-light/` 和 `artifacts/prefetch-dark-narrow/`（不提交）。本次功能验收没有请求真实订阅、抓取第三方文章或调用模型；线上来源的全文提取成功率需以实际刷新结果为准。

## 历史环境记录（保留，不代表当前本机）

以下为仓库原有记录，其中的系统版本、工具链和 Xcode 缺失状态与当前本机不同。

### 初始化时检查

| 项目 | 本机结果 |
| --- | --- |
| Swift | Apple Swift 6.3.1，swiftlang-6.3.1.1.2 |
| 编译目标 | arm64-apple-macosx26.0 |
| 活动开发目录 | /Library/Developer/CommandLineTools |
| 完整 Xcode | /Applications 下未检测到 Xcode.app |
| xcodebuild | 当前失败：活动目录是 Command Line Tools，需要完整 Xcode |

初始化时仅检查工具版本；后续同日已完成下述实际构建验证。
完整 Xcode 用于 App 工程、SwiftUI 预览、模拟器与签名调试。

### 历史准备建议

1. 从 Mac App Store 或 Apple Developer 官方渠道安装与本机 macOS 兼容的稳定版 Xcode。
2. 打开 Xcode，完成首次启动、许可与所需平台组件安装。
3. 在 Xcode Settings → Locations 中选择对应的 Command Line Tools。
4. 检查：

```sh
xcode-select -p
xcodebuild -version
xcrun swift --version
xcrun --sdk macosx --show-sdk-path
```

期望活动开发目录为所安装 Xcode 的 Contents/Developer。
如使用标准安装路径，也可以在确认安装完成后执行：

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

初始化阶段没有安装 Xcode、切换全局开发目录、接受许可或配置开发者账号。
未选择最低 macOS 版本；后续根据依赖与目标用户确定。

## 官方参考

- SwiftUI：https://developer.apple.com/swiftui/
- Xcode：https://developer.apple.com/xcode/

下一步建立工程时优先使用 Xcode 与 Swift Package Manager，不预先安装额外包管理器或工程生成器。

## 历史 Demo 实测补充（2026-11-09）

- 本机 macOS 26.5.1 / arm64，Swift 6.3.1，Command Line Tools 内 macOS SDK 26.4.1。
- 已通过 `swift build` 编译 SwiftUI + AppKit + WebKit + JavaScriptCore 和两个固定版本 SPM 依赖。
- `bash scripts/build-app.sh` 生成 `dist/Topic Reader.app`，附带许可证与资源，并完成 ad-hoc 签名验证。
- 完整 Xcode 缺失不阻碍此 Demo 的命令行编译；`xcodebuild`、SwiftUI 预览等完整工程能力仍需安装 Xcode。
- 未安装 Xcode、切换全局工具链或配置开发者账号。
- 本机网络存在系统代理与终端代理差异。App 提供本机 HTTP/SOCKS5 代理配置；命令行 `--refresh-demo --use-environment-proxy` 可沿用环境中已配置的无认证回环代理，并保存到 App 偏好设置。不会全局关闭 ATS。

视觉验收：`READER_SNAPSHOT_DIR=/tmp/reader-light "dist/Topic Reader.app/Contents/MacOS/TopicReader" --visual-check`；可附加 `--dark`、`--narrow`、`--lower`。该模式使用合成文章，不访问网络、不写入阅读缓存；`--live-data` 可只读展示已有缓存。截图由应用自身视图与 WebKit 快照生成，不需要截取其他应用。

## 历史联网实测结果（本轮未重新验证）

2026-11-09，在本机配置的 SOCKS5 回环代理下完成一轮显式刷新：

| 来源 | 获取条数 | 本轮结果 |
| --- | ---: | --- |
| Lequn Chen | 10 | 成功 |
| Horace He | 0 | 本机 DNS 解析失败，未跳过安全校验 |
| Interconnects | 20 | 成功 |
| Lilian Weng | 40 | 成功，达到 Demo 每源处理上限 |
| 苏剑林 | 10 | 成功 |
| vLLM | 40 | 成功，达到 Demo 每源处理上限 |

共 120 篇本地缓存文章。来源可用性会变化，此结果不代表永久可用；界面记录下一次刷新结果。已在打包 App 中对一篇 Lilian Weng 文章执行真实 Readability 提取，得到 58,860 字节清理 HTML，保留原抓取页面和订阅内容。

23 项离线检查全部通过；亮色/暗色/窄窗口及真实缓存文章完成视图快照检查。VoiceOver 全流程、最低系统版本和 Intel Mac 尚未实测。
