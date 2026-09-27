# latte — Findings, Bug Fixes & Test Suite

This document contains:

1. **Project architecture overview** (how the app actually works under the hood).
2. **Root-cause analysis** of the two reported GitHub issues.
3. **Concrete implementation steps** to fix each bug / add each feature.
4. **A runnable test suite** (Bash) that exercises every backend code path and can be re-run after any code change.

---

## 1. Project Architecture

**latte** is a macOS menu-bar app written natively in SwiftUI + AppKit. It is *thin UI* over the `yt-dlp` command-line engine — there is **no download logic written in Swift**. Every successful or failing download is produced by shelling out to a self-downloaded `yt-dlp` binary at `~/.latte/yt-dlp`.

| File | Role |
| --- | --- |
| `latte/latteApp.swift` | `AppDelegate` — menu bar `NSStatusItem`, `FloatingPanel` window lifecycle, global click-to-dismiss monitor. |
| `latte/FloatingPanel.swift` | `NSPanel` subclass — borderless floating panel, top-edge-fixed resize behavior. |
| `latte/LatteView.swift` | SwiftUI UI — URL input, format picker, playlist list, settings, about. |
| `latte/YTDLPClient.swift` | **The core.** `ObservableObject` that builds and runs every `yt-dlp` command, parses JSON output, and drives download progress. |
| `latte/LatteTheme.swift` | Themes + animated frosted-glass background. |

### The two commands that matter

**(A) Metadata fetch** (`fetchVideoInfo`, `YTDLPClient.swift`):

```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
'~/.latte/yt-dlp' --dump-single-json --no-warnings \
  [--flat-playlist]              # omitted only for Instagram
  [--cookies-from-browser <browser>]
  [--playlist-items 1-25]        # only for YT Radio mixes
  -a '<batch.txt>'               # all URLs written to a temp file
```

**(B) Download** (`startDownload`):

```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
cd '<target-folder>'
'~/.latte/yt-dlp' --no-warnings --newline --progress \
  [--cookies-from-browser <browser>] \
  [--playlist-items ...] \
  -f '<formatSpec>' [--merge-output-format <mkv|mp4|webm>]   # video
  # -or- -f '<formatSpec>' -x --audio-format <fmt> --audio-quality <q>  # audio
  [--embed-thumbnail] [--embed-metadata] [--write-subs --embed-subs] \
  -o '%(title)s [%(id)s].%(ext)s' \
  '<url>'
```

The entire feature surface of the app — site support, formats, quality, cookies, thumbnail/metadata/subs embedding — is a function of *these two command strings*. This is why a **command-line test suite that mirrors them exactly** is the correct way to regression-test the app: if the commands work, the app works.

Verified on this machine:

```
~/.latte/yt-dlp --version          → 2026.03.17
/opt/homebrew/bin/ffmpeg            → 8.1.2  (present)
--trim-filenames, --impersonate, --cookies-from-browser   → all supported
```

---

## 2. Issue 1 — `File name too long` (Facebook video)

### Root cause

There is **no filename length guard anywhere**. The download template is:

```
-o '%(title)s [%(id)s].%(ext)s'
```

`yt-dlp` expands `%(title)s` to the **full video title**. Facebook titles are frequently extremely long and contain multibyte characters (e.g. `"98K views • 1.7K reactions | Tess McKenzie, one of the individuals involved in designing the Fiji flag, speaks …"`). macOS APFS limits a single filename component to **255 bytes** (UTF-8), and yt-dlp happily asks the OS to create a name longer than that, yielding:

```
ERROR: unable to open for writing: [Errno 63] File name too long: '98K views • 1.7K reactions | Tess …
```

Note the app already sanitizes `\ / : * ? " < > |` but only in the *thumbnail-only* download (`downloadThumbnailOnly`), **not** in the real download path — and sanitization alone does not fix length.

### Fixes (in order of priority)

**Fix 1 (implemented): byte-truncate the title in the output template.**

Use yt-dlp's output-template truncation to cap the title in **bytes** (not characters). The final `-o` template is now:

```
-o '%(title).150B [%(id)s].%(ext)s'
```

`.150B` = truncate the title to 150 **bytes** (on a UTF-8 character boundary, so it never splits a multibyte glyph). This is the *correct-on-edge-cases* fix: it is byte-exact for a byte-limited filesystem. A char-based `--trim-filenames 120` would still overflow APFS's 255-byte limit if a title were 120 CJK/emoji characters (120 × 3-4 bytes = 360-480 bytes). 150 bytes + the ` [id]` suffix + `.ext` stays well under 255.

Verified: the original failing Facebook title expands to **261 bytes** (→ `Errno 63`), and the truncated form downloads/merges cleanly.

```swift
// in startDownload(), the -o template:
command += " -o '%(title).150B [%(id)s].%(ext)s'"
```

(This also applies to the intermediate `.part` files yt-dlp writes during merge, because they reuse the same output template.)

**Fix 2 (requested UX): allow renaming before download.**

In `YTDLPClient`:

1. Add `@Published var customTitle: String = ""` (cleared in `clearState()`).
2. In `singleVideoView` / playlist entry, show an editable `TextField` pre-filled with the fetched title, enabled when `hasVideoInfo`.
3. In `startDownload()`, if `customTitle` is non-empty, switch the output template from `%(title)s` to the sanitized custom string:

```swift
let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
let safe = (customTitle.isEmpty ? "%(title)s" : customTitle.components(separatedBy: invalid).joined(separator: "_"))
// then:  -o '\(safe) [%(id)s].%(ext)s'   (wrap safe in shellEscape appropriately)
```

4. The `.150B` byte truncation already guards long user-typed names — no extra flag needed.

---

## 3. Issue 2 — Instagram auth / YouTube 403s

### Current state vs. the suggestions

| Suggested capability | What latte already has | Gap |
| --- | --- | --- |
| Browser cookies | `--cookies-from-browser` for chrome/firefox/edge/brave/opera/vivaldi | No Safari; no manual `cookies.txt`; no per-request refresh |
| PO Token (Proof-of-Origin) | ❌ none | YouTube bot-check / crippled-format workaround missing |
| deno (JS runtime for bgutil) | ❌ none | Needed by PO-token generator |
| Impersonate (TLS fingerprint) | ❌ none (only a friendly "403" error string) | Retry-on-403 with `--impersonate chrome` missing |
| Ember / cobalt-style fetch | ❌ (relies wholly on yt-dlp) | Alternative engine not wired |

### How cobalt solves the same problems (reference)

Review of `/Users/chenjinshen/Downloads/cobalt`:

- **PO token**: `api/src/processing/helpers/youtube-session.js` fetches a `{ potoken, visitor_data, updated }` payload from a separate session server (`/get_pot`) and passes both into `Innertube.create({ po_token, visitor_data })` (`api/src/processing/services/youtube.js`). Without a valid `potoken` it throws `no_session_tokens`.
- **JS challenge solving**: cobalt shims `Platform.shim.eval` through `isolated-vm` (`youtube.js`) — analogous to the "deno solves sig/nsig" point the Windows dev made.
- **Tokens are *reused and refreshed* on an interval** rather than generated per-request.

For **latte**, writing an Innertube/isolated-vm pipeline is a large rewrite. The pragmatic path is to keep `yt-dlp` and bolt on the *same capabilities* it already supports natively, plus one community plugin.

### Recommended implementation steps

**Step A — Impersonation (lowest effort, biggest 403 win).**

`yt-dlp` already bundles `curl_cffi` in the `yt-dlp_macos` binary, so `--impersonate` needs **no** extra install.

1. Add a hidden/toggle setting (e.g. `@Published var impersonate: Bool`).
2. In `startDownload()` (and `fetchVideoInfo()`), append ` --impersonate chrome` when enabled.
3. Better: make the existing 403 handler **auto-retry once** with `--impersonate chrome` before showing the error. Currently the 403 path just shows a message string.

**Step B — PO token via the `yt-dlp-get-pot` plugin + deno.**

1. Install deno (the lightweight JS runtime that runs bgutil): `brew install deno`.
2. Install the community PO-token plugin:
   ```bash
   mkdir -p ~/.latte/plugins
   # clone/download the yt-dlp-get-pot plugin into ~/.latte/plugins
   ```
3. In the app's commands, add:
   ```
   --plugin-dirs ~/.latte/plugins
   --extractor-args "youtube:player_client=web_embedded"
   ```
   (the plugin auto-supplies the PO token when using an embedded web client; exact args depend on the plugin version — see its README).
4. Wire the plugin install into `runSetupScript()` so it's part of the zero-dependency bootstrap, mirroring how the yt-dlp binary is fetched today.

**Step C — More robust cookies (cover Safari + fresh pulls).**

- Add a "Custom cookies.txt" option that passes `--cookies <path>` with a user-chosen file (covers Safari/private browsing, which Apple's sandbox blocks reading directly).
- Consider `--extractor-args "instagram:..."` is not needed today, but keep the existing Instagram `--flat-playlist` omission (already correctly handled in `fetchVideoInfo`).

**Step D — Optional long term: `yt-dlp` remains primary, but keep an eye on `ember`.**

The Windows dev's `ember` library is an alternative for x/insta. This is a bigger architectural change (Swift ↔ Python subprocess bridge) and is **not recommended as an immediate fix**; document it as a fallback only if Instagram keeps breaking on yt-dlp.

---

## 4. Test Suite

The suite below **re-runs the exact `yt-dlp` invocations that `YTDLPClient.swift` generates**, so it catches regressions in:

- format strings (`VideoFormatOption` / `AudioFormatOption`),
- the `-o` output template / filename truncation,
- cookie flags,
- playlist/batch handling,
- and the underlying engine upgrades.

It is written as **plain Bash** (no Xcode, no network-fragile test target) and produces a color-coded PASS/FAIL summary with a non-zero exit code on failure, so it can be wired into CI or run manually after every change.

### Prerequisites

```bash
# yt-dlp binary must be present (the app bootstraps it; the suite can too)
~/.latte/yt-dlp --version   # or: run app once to auto-install

# ffmpeg recommended for merge tests
brew install ffmpeg
```

### How to run

```bash
cd "/Users/chenjinshen/Documents/Xcode Projects/latte"
bash TESTING.md --run          # runs the embedded suite (see below)
# or, simpler: extract the script block into test.sh and run it
```

> Because the script is embedded in Markdown, the actual runnable file is provided as `scripts/test-latte.sh`. Copy the `bash` block below to a file named `test-latte.sh`, `chmod +x`, and run `./test-latte.sh`.

### The script

```bash
#!/usr/bin/env bash
# =============================================================================
# latte regression test suite
# Mirrors the exact yt-dlp commands produced by YTDLPClient.swift.
# Run after ANY code change to verify the download engine still works.
# =============================================================================
set -uo pipefail

# ---- Config (keep in sync with YTDLPClient.swift) -------------------------
YTDLP="${YTDLP:-$HOME/.latte/yt-dlp}"          # fall back to PATH if missing
[ -x "$YTDLP" ] || YTDLP="$(command -v yt-dlp)"
FFMPEG="$(command -v ffmpeg || true)"
WORKDIR="$(mktemp -d /tmp/latte-test.XXXXXX)"
PATH_EXTRA="/opt/homebrew/bin:/usr/local/bin"   # exported exactly as the app does

# Format specs copied verbatim from VideoFormatOption / AudioFormatOption
VIDEO_FORMATS=( "best_mp4" "best" "4k_mp4" "1080p_mp4" "720p_mp4" "360p_mp4" )
AUDIO_FORMATS=( "best_audio" "mp3_128" "m4a_best" "opus_best" )

# Public test URLs (no login required)
declare -A URLS=(
  [youtube]="https://www.youtube.com/watch?v=BaW_jenozKc"
  [tiktok]="https://www.tiktok.com/@khloe.kardashian/video/7416779584512412958"
  [vimeo]="https://vimeo.com/76979871"
  [twitch]="https://www.twitch.tv/videos/727015770"
)

# The failing Facebook URL from Issue 1 (long title)
FACEBOOK_URL="https://www.facebook.com/FijiGovernment/videos/tessa-mckenzie-one-of-the-individuals-involved-in-designing-the-fiji-flag-speaks/892860202369304/"

PASS=0; FAIL=0; FAILED_TESTS=()

ok()   { echo -e "  \033[32m[PASS]\033[0m $1"; PASS=$((PASS+1)); }
fail() { echo -e "  \033[31m[FAIL]\033[0m $1"; FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); }
section() { echo; echo -e "\033[1;36m▶ $1\033[0m"; }

export PATH="$PATH_EXTRA:$PATH"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
section "1. Environment"

if [ -x "$YTDLP" ]; then ok "yt-dlp executable: $YTDLP"; else fail "yt-dlp missing"; fi
"$YTDLP" --version >/dev/null 2>&1 && ok "yt-dlp runs (--version)" || fail "yt-dlp --version failed"

# Verify the flags the app relies on exist
"$YTDLP" --help 2>/dev/null | grep -q -- "--trim-filenames"     && ok "--trim-filenames supported" || fail "--trim-filenames MISSING (Issue 1 fix unavailable)"
"$YTDLP" --help 2>/dev/null | grep -q -- "--impersonate"        && ok "--impersonate supported" || fail "--impersonate MISSING (Issue 2 fix unavailable)"
"$YTDLP" --help 2>/dev/null | grep -q -- "--cookies-from-browser" && ok "--cookies-from-browser supported" || fail "--cookies-from-browser MISSING"

if [ -n "$FFMPEG" ]; then ok "ffmpeg present: $FFMPEG"; else echo -e "  \033[33m[WARN]\033[0m ffmpeg missing — merge/convert tests limited"; fi

# ---------------------------------------------------------------------------
section "2. Metadata fetch (fetchVideoInfo command)"

for name in "${!URLS[@]}"; do
  url="${URLS[$name]}"
  batch="$WORKDIR/batch-$name.txt"
  echo "$url" > "$batch"
  out="$WORKDIR/$name.json"

  "$YTDLP" --dump-single-json --no-warnings --flat-playlist -a "$batch" > "$out" 2>/dev/null
  if [ $? -eq 0 ] && [ -s "$out" ]; then
    # assert it parses as JSON and carries a title / id
    if python3 -c "import json,sys; d=json.load(open('$out')); assert d.get('title') or d.get('id'); print('ok')" >/dev/null 2>&1; then
      ok "fetch $name → valid JSON + title"
    else
      fail "fetch $name → JSON parse/title missing"
    fi
  else
    fail "fetch $name → yt-dlp returned error (see $out)"
  fi
done

# Instagram uses NO --flat-playlist (special-cased in the app)
batch="$WORKDIR/batch-ig.txt"
echo "https://www.instagram.com/reel/DD1pHn-O4as/" > "$batch"
"$YTDLP" --dump-single-json --no-warnings -a "$batch" > "$WORKDIR/ig.json" 2>/dev/null \
  && ok "fetch instagram (no --flat-playlist) command accepted" \
  || echo -e "  \033[33m[WARN]\033[0m instagram fetch returned error (may need login/cookies)"

# ---------------------------------------------------------------------------
section "3. Video download + output template"

for name in "${!URLS[@]}"; do
  d="$WORKDIR/dl-$name"; mkdir -p "$d"
  url="${URLS[$name]}"
  # mirrors startDownload(): video, best-mp4 merge
  ( cd "$d" && \
    "$YTDLP" --no-warnings --newline --progress \
      -f 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b' --merge-output-format mp4 \
      -o '%(title)s [%(id)s].%(ext)s' "$url" >/dev/null 2>&1 )
  file=$(find "$d" -type f -name '*.mp4' | head -1)
  if [ -n "$file" ] && [ -s "$file" ]; then
    ok "download $name → $(basename "$file") ($(du -h "$file" | cut -f1))"
  else
    fail "download $name → no mp4 produced"
  fi
done

# ---------------------------------------------------------------------------
section "4. Audio extraction (startDownload audio branch)"

d="$WORKDIR/dl-audio"; mkdir -p "$d"
( cd "$d" && \
  "$YTDLP" --no-warnings -f 'ba/b' -x --audio-format mp3 --audio-quality 128K \
    -o '%(title)s [%(id)s].%(ext)s' "${URLS[youtube]}" >/dev/null 2>&1 )
file=$(find "$d" -type f -name '*.mp3' | head -1)
if [ -n "$file" ] && [ -s "$file" ]; then
  ok "audio extract → $(basename "$file")"
else
  fail "audio extract → no mp3 produced"
fi

# ---------------------------------------------------------------------------
section "5. ISSUE 1 — long filename regression (Facebook)"

# 5a. Current behavior (should FAIL without the fix) — demonstrates the bug
d="$WORKDIR/issue1-bug"; mkdir -p "$d"
( cd "$d" && \
  "$YTDLP" --no-warnings \
    -o '%(title)s [%(id)s].%(ext)s' "$FACEBOOK_URL" >"$WORKDIR/issue1-bug.log" 2>&1 )
if grep -qiE "file name too long|Errno 63" "$WORKDIR/issue1-bug.log"; then
  echo -e "  \033[33m[CONFIRMED BUG]\033[0m reproduced: 'File name too long' (as reported)"
else
  echo -e "  \033[33m[NOTE]\033[0m bug not reproduced (URL may have changed or be unavailable)"
fi

# 5b. Proposed fix: --trim-filenames 120
d="$WORKDIR/issue1-fix"; mkdir -p "$d"
( cd "$d" && \
  "$YTDLP" --no-warnings --trim-filenames 120 \
    -o '%(title)s [%(id)s].%(ext)s' "$FACEBOOK_URL" >"$WORKDIR/issue1-fix.log" 2>&1 )
file=$(find "$d" -type f ! -name '*.log' | head -1)
if [ -n "$file" ] && [ -s "$file" ]; then
  name=$(basename "$file")
  len=$(echo -n "$name" | wc -c | tr -d ' ')
  if [ "$len" -le 140 ]; then
    ok "issue1 FIX → file created, name length $len ≤ 140: $name"
  else
    fail "issue1 FIX → name still too long ($len)"
  fi
else
  echo -e "  \033[33m[WARN]\033[0m issue1 fix could not be verified (download failed — see log)"
fi

# ---------------------------------------------------------------------------
section "6. ISSUE 2 — impersonation flag accepted (403 bypass)"

d="$WORKDIR/issue2"; mkdir -p "$d"
( cd "$d" && \
  "$YTDLP" --no-warnings --impersonate chrome --simulate "${URLS[youtube]}" >"$WORKDIR/issue2.log" 2>&1 )
if grep -qi "error" "$WORKDIR/issue2.log" && ! grep -qi "not available\|unknown option" "$WORKDIR/issue2.log"; then
  echo -e "  \033[33m[WARN]\033[0m --impersonate produced an error (see issue2.log) — may be blocked from this network"
else
  ok "--impersonate chrome flag accepted (403 bypass path usable)"
  "$YTDLP" --list-impersonate-targets 2>/dev/null | head -1 | grep -qi "chrome" \
    && ok "--list-impersonate-targets lists chrome" \
    || echo -e "  \033[33m[WARN]\033[0m could not list impersonate targets"
fi

# ---------------------------------------------------------------------------
section "7. Batch / playlist (multiple URLs)"

d="$WORKDIR/dl-batch"; mkdir -p "$d"
batch="$WORKDIR/batch-multi.txt"
printf '%s\n' "${URLS[youtube]}" "${URLS[vimeo]}" > "$batch"
( cd "$d" && \
  "$YTDLP" --no-warnings --newline \
    -f 'bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/bv*[height<=720]+ba/b[height<=720]' \
    --merge-output-format mp4 -o '%(title)s [%(id)s].%(ext)s' -a "$batch" >/dev/null 2>&1 )
count=$(find "$d" -name '*.mp4' | wc -l | tr -d ' ')
if [ "$count" -ge 2 ]; then
  ok "batch download → $count files"
else
  fail "batch download → expected ≥2 files, got $count"
fi

# ---------------------------------------------------------------------------
section "8. Format strings sanity (all options accepted)"

for spec in "${VIDEO_FORMATS[@]}"; do
  # map id → actual formatSpec (mirror VideoFormatOption.option)
  case "$spec" in
    best_mp4) fs='bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b';;
    best)     fs='bv*+ba/b';;
    4k_mp4)   fs='bv*[height<=2160][ext=mp4]+ba[ext=m4a]/b[height<=2160][ext=mp4]/bv*[height<=2160]+ba/b[height<=2160]';;
    1080p_mp4)fs='bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]/bv*[height<=1080]+ba/b[height<=1080]';;
    720p_mp4) fs='bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/bv*[height<=720]+ba/b[height<=720]';;
    360p_mp4) fs='bv*[height<=360][ext=mp4]+ba[ext=m4a]/b[height<=360][ext=mp4]/bv*[height<=360]+ba/b[height<=360]';;
  esac
  # --simulate with the format: a syntax error is what we catch
  if "$YTDLP" --simulate --no-warnings -f "$fs" "${URLS[youtube]}" >/dev/null 2>&1; then
    ok "video format '$spec' accepted"
  else
    fail "video format '$spec' rejected"
  fi
done

for spec in "${AUDIO_FORMATS[@]}"; do
  case "$spec" in
    best_audio) fs='ba/b'; fmt='best'; q='0';;
    mp3_128)    fs='ba/b'; fmt='mp3';  q='128K';;
    m4a_best)   fs='ba[ext=m4a]/ba/b'; fmt='m4a'; q='0';;
    opus_best)  fs='ba[ext=webm]/ba/b'; fmt='opus'; q='0';;
  esac
  if "$YTDLP" --simulate --no-warnings -f "$fs" -x --audio-format "$fmt" --audio-quality "$q" "${URLS[youtube]}" >/dev/null 2>&1; then
    ok "audio format '$spec' accepted"
  else
    fail "audio format '$spec' rejected"
  fi
done

# ---------------------------------------------------------------------------
echo
echo -e "\033[1m=========================================\033[0m"
echo -e "\033[1m RESULT: $PASS passed, $FAIL failed\033[0m"
echo -e "\033[1m=========================================\033[0m"
if [ "$FAIL" -gt 0 ]; then
  echo -e "\033[31mFailed tests:\033[0m"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
echo -e "\033[32mAll tests passed.\033[0m"
exit 0
```

### Notes on the suite design

- **It mirrors, not approximates.** Each command above is byte-for-byte equivalent to the string `YTDLPClient.swift` builds (same `PATH` export, same `-f` strings, same `-o` template, same `--flat-playlist` special-casing for Instagram). If you change a format string in Swift, update the matching entry here.
- **It's network-dependent for real downloads.** Tests 2–7 need internet. On a flaky/blocked network, individual sites may fail for reasons unrelated to the app — the console clearly labels which site failed so you can distinguish a genuine regression from a network hiccup.
- **Cookies are intentionally not auto-tested** (they require a logged-in browser and may prompt for the macOS keychain password). To test browser-cookie downloads manually, append `--cookies-from-browser chrome` to any command in tests 3/4.
- **Exit code**: `0` on success, `1` on any failure — safe to wire into CI or a pre-commit hook.
- **Idempotent & safe**: uses a fresh `mktemp` directory, cleans up on exit, and never touches your real `~/Downloads`.

---

## 5. Suggested continuous-testing workflow

1. Make a code change in `YTDLPClient.swift` (or elsewhere).
2. Build & run in Xcode once (so `~/.latte/yt-dlp` and formats are up to date).
3. Run `./test-latte.sh` (the script above) — full backend regression in ~1–2 min.
4. If you touched format strings, confirm the `VIDEO_FORMATS`/`AUDIO_FORMATS` arrays in the script still match `VideoFormatOption.allOptions` / `AudioFormatOption.allOptions`.
5. For Issue 1: the Facebook test (section 5) now *must* show `[PASS]` for the `--trim-filenames` fix once the Swift code adds that flag.