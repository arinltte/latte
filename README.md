<p align="center">
  <img src="public/lattelogo.jpg" alt="latte Logo" width="64" />
  <br />
  <h1 align="center">latte</h1>
  <p align="center">Just Download Anything.</p>
  <p align="center">
    <a href="https://github.com/arinltte/latte/releases/latest"><img src="https://img.shields.io/github/v/release/arinltte/latte?style=flat-square&color=blue" alt="Latest Release" /></a>
    <a href="https://github.com/arinltte/latte/blob/main/LICENSE"><img src="https://img.shields.io/github/license/arinltte/latte?style=flat-square&color=green" alt="License" /></a>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-blue?style=flat-square" alt="macOS" />
    <img src="https://img.shields.io/badge/app%20memory-%3C50MB-brightgreen?style=flat-square" alt="Memory" />
  </p>
</p>

---

**latte** is a lightweight, ultra-fast video and audio downloader for macOS that lives entirely in your menu bar. Built natively with SwiftUI, it allows you to download media from thousands of popular websites instantly—without opening a browser tab, dealing with ads, or navigating complex command-line tools.

<video src="https://github.com/user-attachments/assets/606b279f-7a26-4977-8e6a-1e596f7245e9" controls width="800"></video>

---

## 🏗️ Features

- **Menu bar native** — Lives quietly in your menu bar. No Dock icon, no persistent window, no interruption to your workflow.
- **Universal support** — Supports downloading from over 1,000+ popular platforms including YouTube, Twitch, TikTok, Vimeo, Facebook, Instagram, Twitter, and major news/sports outlets.
- **Browser Authentication** — Securely inject cookies from Chrome, Firefox, Brave, or Edge to download age-restricted, private, or login-required content. 
- **Batch downloading** — Paste multiple links at once. The UI automatically collapses to save space while fetching massive playlists or batches in the background.
- **Advanced format management** — Reorder your preferred video and audio formats (supports modern codecs like AV1, WebM, MKV, FLAC, ALAC). **Show/hide formats** you don't use to keep your interface perfectly clean.
- **Smart Auto-Dismiss & Pinning** — Click anywhere outside the app to hide it instantly, or use the "Keep Window Open" toggle to pin it to your screen.
- **Post-processing made easy** — Automatically embed thumbnails, inject metadata, and burn subtitles directly into your downloaded files.
- **Zero-dependency setup** — Automatically configures its own fast backend engine (`yt-dlp`) locally. No manual Python or terminal setup required.
- **Premium ambient design** — Features a stunning, zero-overhead animated frosted glass interface (choose between Default, Rare Jade, Deep Ocean, or Floral themes).

---

## Requirements

- macOS 14 (Sonoma) or later.
- **ffmpeg** is recommended for merging high-quality video/audio formats and converting to specific audio types.
  - Install via Homebrew: `brew install ffmpeg`

---

## 🚀 Installation

### Recommended

Download the latest `.dmg` from the [Releases](https://github.com/arinltte/latte/releases/latest) page, open it, and drag **latte** to your Applications folder.

### Gatekeeper

If macOS blocks the app on first launch, run the following in Terminal after installation:

```bash
xattr -rd com.apple.quarantine /Applications/latte.app
```

> **Note:** Your Terminal application may require **Full Disk Access** before this command works.
> Grant it under **System Settings → Privacy & Security → Full Disk Access**, then run the command above.

---

## 🔒 Restricted Content & Authentication

latte allows you to download private, age-restricted, or login-required content (like private Instagram Reels/Stories or Reddit videos) by securely reading the cookies from your daily web browser.

1. Go to **Settings** in latte.
2. Select your primary browser under **Browser Cookies** (Chrome, Firefox, Brave, or Edge).
3. Ensure you are logged into the target website on your browser's Default Profile.

*(Note: During the extraction process, macOS may prompt you to enter your system password to allow latte to access the browser's encrypted cookie database).*

### Verified Browsers & Limitations
- **Google Chrome** is heavily tested and officially verified for the best experience with latte's authentication feature.
- **Safari** is not supported due to severe macOS Sandboxing restrictions that block cookie access.
- **Instagram Stories**: Private IG Stories can be downloaded! However, because Instagram doesn't provide standard titles for Stories, latte will display nothing. You can still click Download and it will save perfectly.
- **Private Facebook Videos**: Currently, downloading *private* Facebook videos fails with a "Cannot parse data" error. This is a known limitation of the underlying backend engine. Public Facebook videos work normally. 

*(Encountering issues with other restricted websites? Please open an issue in the GitHub issues panel).*

---

## Getting Started

1. Click the latte icon in your menu bar.
2. Paste a video link (or multiple links on separate lines) into the text box.
3. Select whether you want to download a **Video** or **Audio** file.
4. Click **Download**.
5. Press **Escape** or click anywhere outside the window to dismiss the panel at any time.

---

## 📂 Data & Privacy

latte stores the following data locally on your machine and nowhere else:

| Location | Contents |
| --- | --- |
| `~/.latte/` | Backend engine (`yt-dlp`), temporary cache, and configuration |
| `~/Library/Preferences/com.arinltte.latte.plist` | App preferences (download folder, format priorities, themes) |

No usage data, download history, or telemetry of any kind are transmitted externally.

To perform a complete uninstall and remove all application data:

```bash
rm -rf ~/.latte
rm -f ~/Library/Preferences/com.arinltte.latte.plist
rm -rf ~/Library/Application\ Support/com.arinltte.latte 2>/dev/null
rm -rf ~/Library/Saved\ Application\ State/com.arinltte.latte.savedState 2>/dev/null
killall cfprefsd
```

---

## 🌐 Supported Sites

latte is powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp) and supports downloading from **1,800+ websites**, including:

- **Video platforms**: YouTube, Vimeo, Dailymotion, Twitch, Rumble, Odysee, PeerTube
- **Social media**: TikTok, Instagram, Facebook, Twitter/X, Reddit, Tumblr, Pinterest
- **Music & audio**: SoundCloud, Bandcamp, Mixcloud, Audiomack
- **News & media**: BBC, CNN, NPR, Reuters, ABC, NBC, CBS, The Guardian, Bloomberg
- **Sports**: ESPN, MLB, NBA, NFL, Olympics
- **Asian platforms**: Bilibili, Niconico, Youku, iQIYI, Weibo
- **Live streams**: Twitch, YouTube Live, Kick, Steam Community
- **Podcasts & radio**: Apple Podcasts, Spotify, Stitcher, iHeartRadio

And many more. You can also view the full list directly within the app under **Settings → Supported Sites**.

For the complete and always up-to-date list, see the [yt-dlp supported sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md) documentation.

---

## 🤝 Contributing

Contributions are welcome. Whether it's a bug report, a feature suggestion, a documentation improvement, or a pull request — all are appreciated.

**To contribute:**

1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes with a clear message.
4. Open a pull request against `main` with a description of what you changed and why.

**To report a bug or request a feature**, open an [issue](https://github.com/arinltte/latte/issues). Please include your macOS version and steps to reproduce for bug reports.

---

## Building from Source

```bash
git clone https://github.com/arinltte/latte.git
cd latte
open latte.xcodeproj
```

Build and run the `latte` scheme in Xcode. Requires Xcode 16 or later.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

<p align="center">
  <i>Developed by arinltte · cjshen00@gmail.com</i>
</p>
