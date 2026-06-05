<p align="center">
  <img src="public/lattelogo.jpg" alt="latte Logo" width="64" />
  <br />
  <h1 align="center">latte</h1>
  <p align="center">即刻下载，万物皆可获取。</p>
  <p align="center">
    <a href="https://github.com/arinltte/latte/releases/latest"><img src="https://img.shields.io/github/v/release/arinltte/latte?style=flat-square&color=blue" alt="Latest Release" /></a>
    <a href="https://github.com/arinltte/latte/blob/main/LICENSE"><img src="https://img.shields.io/github/license/arinltte/latte?style=flat-square&color=green" alt="License" /></a>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?style=flat-square" alt="macOS" />
    <img src="https://img.shields.io/badge/内存占用-%3C50MB-brightgreen?style=flat-square" alt="Memory" />
  </p>
</p>

<p align="center">
  <a href="./README.md">English</a> | <a href="./README-ZH.md">中文文档</a>
</p>
由Qwen3.7-MAX翻译，如有错误敬请谅解。

---

**latte** 是一款轻量、极速的 macOS 菜单栏音视频下载工具。它采用原生 SwiftUI 构建，让你无需打开浏览器、免受广告干扰或折腾复杂的命令行，即可瞬间从数千个热门网站下载媒体文件。

<video src="https://github.com/user-attachments/assets/606b279f-7a26-4977-8e6a-1e596f7245e9" controls width="800"></video>

---

## 🏗️ 核心特性

- **原生菜单栏应用** — 静默驻留菜单栏。无 Dock 图标，无持久窗口，不打断工作流。
- **海量网站支持** — 支持从 YouTube、Twitch、TikTok、Vimeo、Facebook、Instagram、Twitter 及各大新闻/体育网站等 1000+ 平台下载。
- **浏览器身份验证** — 安全读取 Chrome、Firefox、Brave 或 Edge 的 Cookie，轻松下载受限、私密或需登录的内容。
- **批量下载** — 支持同时粘贴多个链接。在后台抓取大型播放列表或批量任务时，UI 会自动折叠以节省空间。
- **高级格式管理** — 自由排序偏好的音视频格式（支持 AV1、WebM、MKV、FLAC、ALAC 等现代编码）。**显示/隐藏**不常用的格式，保持界面清爽。
- **智能自动隐藏与置顶** — 点击窗口外部即刻隐藏，或开启“保持窗口打开”将其固定在屏幕上。
- **便捷后处理** — 自动嵌入封面缩略图、注入元数据，并将字幕直接烧录至下载的文件中。
- **零依赖配置** — 自动在本地配置极速后端引擎（`yt-dlp`），无需手动安装 Python 或配置终端。
- **极致环境设计** — 惊艳的零负担动画毛玻璃界面（提供默认、Rare Jade、Deep Ocean、Floral 等主题）。

---

## ⚙️ 系统要求

- macOS 14 (Sonoma) 或更高版本。
- 推荐安装 **ffmpeg**，用于合并高质量音视频格式及转换特定音频类型。
  - 通过 Homebrew 安装：`brew install ffmpeg`

---

## 🚀 安装指南

### 推荐方式

从 [Releases](https://github.com/arinltte/latte/releases/latest) 页面下载最新的 `.dmg` 文件，打开后将 **latte** 拖入“应用程序”文件夹。

### 绕过 Gatekeeper 限制

如果 macOS 在首次启动时拦截了应用，请在安装后于终端中运行以下命令：

```bash
xattr -rd com.apple.quarantine /Applications/latte.app
```

> **注意：** 你的终端应用可能需要**完全磁盘访问权限**才能执行此命令。
> 请前往 **系统设置 → 隐私与安全性 → 完全磁盘访问权限** 中授权，然后再运行上述命令。

---

## 🔒 受限内容与身份验证

latte 允许你通过安全读取日常浏览器的 Cookie，来下载私密、年龄受限或需登录的内容（如私密的 Instagram Reels/Stories 或 Reddit 视频）。

1. 打开 latte 的 **设置 (Settings)**。
2. 在 **浏览器 Cookie** 下选择你的主力浏览器（Chrome、Firefox、Brave 或 Edge）。
3. 确保你已在浏览器的默认配置文件中登录了目标网站。

*（注意：在提取过程中，macOS 可能会提示你输入系统密码，以允许 latte 访问浏览器加密的 Cookie 数据库）。*

### 支持的浏览器与已知限制
- **Google Chrome** 经过深度测试，是 latte 身份验证功能体验最佳的官方认证浏览器。
- **Safari** 因 macOS 严格的沙盒限制（阻止 Cookie 访问）而不受支持。
- **Instagram Stories**：支持下载私密 IG Stories！但由于 Instagram 不为 Stories 提供标准标题，latte 界面将显示为空白。直接点击下载即可正常保存。
- **Facebook 私密视频**：目前下载*私密* Facebook 视频会报“无法解析数据 (Cannot parse data)”错误，这是底层后端引擎的已知限制。公开的 Facebook 视频可正常下载。

*（遇到其他受限网站的问题？请在 GitHub Issues 面板中提交 issue）。*

---

## 🏁 快速开始

1. 点击菜单栏中的 latte 图标。
2. 在文本框中粘贴视频链接（支持多行粘贴多个链接）。
3. 选择需要下载 **视频 (Video)** 还是 **音频 (Audio)**。
4. 点击 **下载 (Download)**。
5. 随时按下 **Esc** 键或点击窗口外部即可收起面板。

---

## 📂 数据与隐私

latte 仅将以下数据存储在本地，绝不向外部传输任何使用数据、下载历史或遥测信息：

| 位置 | 内容 |
| --- | --- |
| `~/.latte/` | 后端引擎 (`yt-dlp`)、临时缓存及配置文件 |
| `~/Library/Preferences/com.arinltte.latte.plist` | 应用偏好设置（下载目录、格式优先级、主题等） |

如需彻底卸载并清除所有应用数据，请运行：

```bash
rm -rf ~/.latte
rm -f ~/Library/Preferences/com.arinltte.latte.plist
rm -rf ~/Library/Application\ Support/com.arinltte.latte 2>/dev/null
rm -rf ~/Library/Saved\ Application\ State/com.arinltte.latte.savedState 2>/dev/null
killall cfprefsd
```

---

## 🌐 支持的网站

latte 由 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 驱动，支持从 **1800+** 个网站下载，包括但不限于：

- **视频平台**：YouTube, Vimeo, Dailymotion, Twitch, Rumble, Odysee, PeerTube
- **社交媒体**：TikTok, Instagram, Facebook, Twitter/X, Reddit, Tumblr, Pinterest
- **音乐与音频**：SoundCloud, Bandcamp, Mixcloud, Audiomack
- **新闻媒体**：BBC, CNN, NPR, Reuters, ABC, NBC, CBS, The Guardian, Bloomberg
- **体育赛事**：ESPN, MLB, NBA, NFL, Olympics
- **亚洲平台**：Bilibili, Niconico, Youku, iQIYI, Weibo
- **直播平台**：Twitch, YouTube Live, Kick, Steam Community
- **播客与电台**：Apple Podcasts, Spotify, Stitcher, iHeartRadio

获取最新、最全的支持列表，请参阅 [yt-dlp 支持的网站文档](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)。

---

## 🤝 参与贡献

欢迎任何形式的贡献。无论是提交 Bug 报告、功能建议、改进文档，还是提交 Pull Request，我们都万分感激。

**如何贡献：**

1. Fork 本仓库。
2. 创建特性分支：`git checkout -b feature/your-feature-name`
3. 提交你的更改并附上清晰的提交信息。
4. 向 `main` 分支发起 Pull Request，并描述你的更改内容及原因。

**报告 Bug 或请求新功能**，请提交 [Issue](https://github.com/arinltte/latte/issues)。提交 Bug 时请务必包含你的 macOS 版本及复现步骤。

---

## 🛠️ 从源码构建

```bash
git clone https://github.com/arinltte/latte.git
cd latte
open latte.xcodeproj
```

在 Xcode 中构建并运行 `latte` scheme。需要 Xcode 16 或更高版本。

---

## 📜 开源许可

基于 MIT 许可证分发。详情请参阅 `LICENSE` 文件。

<p align="center">
  <i>由 arinltte 开发 · cjshen00@gmail.com</i>
</p>
