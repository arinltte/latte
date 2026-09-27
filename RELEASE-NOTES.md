# latte v0.3.1 — Release Notes

A small but important update: two long-standing download failures are fixed,
latte now resists the bot checks that block Facebook/Instagram/TikTok/YouTube
downloads, and latte has a brand-new look.

---

## 🎨 New Logo

- latte has a brand-new mascot logo (by [GUMO](https://www.instagram.com/gumoooo._/)),
  replacing the old one across the app icon, the About panel, and the README.
- The previous logo is kept as `public/lattelogo-legacy.jpg`.

---

## 🌟 Community improvements merged

This release also merges several upstream contributor improvements:

- **Persistent thumbnail cache** — thumbnails are cached in memory, so they no
  longer re-download every time the panel is shown.
- **Animated background pauses while the panel is hidden** — less CPU when idle.
- **Safer yt-dlp argument handling** — no raw shell injection for URLs/paths.

## 🐛 Fixed

### 1. "File name too long" error on long titles
- **Before:** downloading a video with a very long title (common on Facebook)
  failed with `ERROR: unable to open for writing: [Errno 63] File name too long`.
- **After:** file names are automatically capped to a safe length. The video ID
  is kept in the name, so files stay unique and the download always succeeds.

### 2. HTTP 403 / "bot check" blocks
- latte can now pretend to be a normal Chrome browser at the network level,
  bypassing the "403 Forbidden" and bot-check walls that sites use to block
  downloaders.
- This is available as a new toggle in **Settings → "Bypass bot checks
  (impersonate Chrome)"**. Turn it on if a site blocks you; most public links
  still work with it off.

---

## ✅ Verified working (with Chrome cookies)

Tested and confirmed downloading from all of these:

- 🎬 **YouTube** — video and audio (MP3 extraction)
- 🎵 **TikTok**
- 📸 **Instagram** Reels
- 📘 **Facebook** videos

Plus: batch (multiple links at once) downloads, and all 12 video/audio quality
options (Best MP4, 4K, 1080p, 720p, MP3 320/256/128, M4A, OPUS, FLAC, etc.).

---

## 🧪 For developers

A regression test suite (`scripts/test-latte.sh`) now mirrors the exact commands
the app runs, so you can confirm everything still works after any code change:

```bash
./scripts/test-latte.sh          # 31 checks: fetch, download, formats, fixes
```

Full findings and fix details are documented in `TESTING.md`.

---

## 📝 Requirements (unchanged)

- macOS 14 (Sonoma) or later
- `ffmpeg` recommended for merging high-quality video/audio (`brew install ffmpeg`)

---

## 🔒 Privacy (unchanged)

No new data collection. Cookies are still read locally from your browser only
when you enable **Browser Cookies** in Settings, and nothing is transmitted
anywhere but to the content host itself.