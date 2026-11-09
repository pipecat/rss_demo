# 开发环境

检查日期：2026-11-09（Asia/Shanghai）。

## 已检查

| 项目 | 本机结果 |
| --- | --- |
| Swift | Apple Swift 6.3.1，swiftlang-6.3.1.1.2 |
| 编译目标 | arm64-apple-macosx26.0 |
| 活动开发目录 | /Library/Developer/CommandLineTools |
| 完整 Xcode | /Applications 下未检测到 Xcode.app |
| xcodebuild | 当前失败：活动目录是 Command Line Tools，需要完整 Xcode |

初始化时仅检查工具版本；后续同日已完成下述实际构建验证。
完整 Xcode 用于 App 工程、SwiftUI 预览、模拟器与签名调试。

## 后续准备

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

## Demo 实测补充（2026-11-09）

- 本机 macOS 26.5.1 / arm64，Swift 6.3.1，Command Line Tools 内 macOS SDK 26.4.1。
- 已通过 `swift build` 编译 SwiftUI + AppKit + WebKit + JavaScriptCore 和两个固定版本 SPM 依赖。
- `bash scripts/build-app.sh` 生成 `dist/Topic Reader.app`，附带许可证与资源，并完成 ad-hoc 签名验证。
- 完整 Xcode 缺失不阻碍此 Demo 的命令行编译；`xcodebuild`、SwiftUI 预览等完整工程能力仍需安装 Xcode。
- 未安装 Xcode、切换全局工具链或配置开发者账号。
- 本机网络存在系统代理与终端代理差异。App 提供本机 HTTP/SOCKS5 代理配置；命令行 `--refresh-demo --use-environment-proxy` 可沿用环境中已配置的无认证回环代理，并保存到 App 偏好设置。不会全局关闭 ATS。

视觉验收：`READER_SNAPSHOT_DIR=/tmp/reader-light "dist/Topic Reader.app/Contents/MacOS/TopicReader" --visual-check`；可附加 `--dark`、`--narrow`、`--lower`。该模式使用合成文章，不访问网络、不写入阅读缓存；`--live-data` 可只读展示已有缓存。截图由应用自身视图与 WebKit 快照生成，不需要截取其他应用。

## 本次实测结果（与用户历史记录分开）

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
