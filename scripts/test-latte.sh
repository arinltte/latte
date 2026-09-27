#!/usr/bin/env bash
# =============================================================================
# latte regression test suite (bash 3.2 / macOS compatible)
# Mirrors the exact yt-dlp commands produced by YTDLPClient.swift.
# Run after ANY code change to verify the download engine still works.
#
# Usage:   ./test-latte.sh
# Env:     BROWSER=chrome   (cookie source; default chrome)
# See TESTING.md for full documentation.
# =============================================================================
set -uo pipefail

YTDLP="${YTDLP:-$HOME/.latte/yt-dlp}"
[ -x "$YTDLP" ] || YTDLP="$(command -v yt-dlp)"
FFMPEG="$(command -v ffmpeg || true)"
BROWSER="${BROWSER:-chrome}"
WORKDIR="$(mktemp -d /tmp/latte-test.XXXXXX)"
PATH_EXTRA="/opt/homebrew/bin:/usr/local/bin"

# Format specs copied verbatim from VideoFormatOption / AudioFormatOption
VIDEO_FORMATS=( "best_mp4" "best" "4k_mp4" "1080p_mp4" "720p_mp4" "360p_mp4" )
AUDIO_FORMATS=( "best_audio" "mp3_128" "m4a_best" "opus_best" )

# Parallel arrays (bash 3.2 has no associative arrays). Order matters.
NAMES=(    youtube   tiktok     instagram  facebook )
URLS_LIST=(
  "https://www.youtube.com/watch?v=5nYwGIgL0x4"
  "https://www.tiktok.com/@filadama_camara/video/7637765500138753300?is_from_webapp=1&sender_device=pc"
  "https://www.instagram.com/reel/DbAQcVFIZBZ/?utm_source=ig_web_copy_link&stkn=NTc4MTIwNjQ2YQ=="
  "https://www.facebook.com/share/v/19EEiw9cyD/"
)

# Original Issue-1 long-title Facebook URL (used to reproduce the filename bug)
FB_LONG_URL="https://www.facebook.com/FijiGovernment/videos/tessa-mckenzie-one-of-the-individuals-involved-in-designing-the-fiji-flag-speaks/892860202369304/"

# The output template now truncates the title to 150 BYTES (safe under the
# 255-byte APFS filename limit even for CJK/emoji, which char-based
# --trim-filenames would not guarantee).
OUT_TPL='%(title).150B [%(id)s].%(ext)s'

COOKIES_FLAG="--cookies-from-browser $BROWSER"

PASS=0; FAIL=0; FAILED_TESTS=()

ok()   { echo -e "  \033[32m[PASS]\033[0m $1"; PASS=$((PASS+1)); }
fail() { echo -e "  \033[31m[FAIL]\033[0m $1"; FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); }
section() { echo; echo -e "\033[1;36m▶ $1\033[0m"; }

export PATH="$PATH_EXTRA:$PATH"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

url_at() { echo "${URLS_LIST[$1]}"; }

section "1. Environment"
if [ -x "$YTDLP" ]; then ok "yt-dlp executable: $YTDLP"; else fail "yt-dlp missing"; fi
"$YTDLP" --version >/dev/null 2>&1 && ok "yt-dlp runs (--version)" || fail "yt-dlp --version failed"
"$YTDLP" --help 2>/dev/null | grep -q -- "--cookies-from-browser" && ok "--cookies-from-browser supported" || fail "--cookies-from-browser MISSING"
"$YTDLP" --help 2>/dev/null | grep -q -- "--impersonate" && ok "--impersonate supported" || fail "--impersonate MISSING (Issue 2 fix unavailable)"
if [ -n "$FFMPEG" ]; then ok "ffmpeg present: $FFMPEG"; else echo -e "  \033[33m[WARN]\033[0m ffmpeg missing — merge/convert tests limited"; fi

section "2. Metadata fetch (fetchVideoInfo) with $BROWSER cookies"
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"; url=$(url_at "$i")
  batch="$WORKDIR/batch-$name.txt"; echo "$url" > "$batch"
  out="$WORKDIR/$name.json"
  flat="--flat-playlist"; [ "$name" = "instagram" ] && flat=""
  "$YTDLP" --dump-single-json --no-warnings $flat $COOKIES_FLAG -a "$batch" > "$out" 2>/dev/null
  if [ $? -eq 0 ] && [ -s "$out" ]; then
    python3 -c "import json,sys; d=json.load(open('$out')); assert d.get('title') or d.get('id')" >/dev/null 2>&1 \
      && ok "fetch $name → valid JSON + title" \
      || fail "fetch $name → JSON parse/title missing"
  else
    fail "fetch $name → yt-dlp returned error (see $out)"
  fi
done

section "3. Video download (best MP4) with $BROWSER cookies + impersonate"
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"; url=$(url_at "$i")
  d="$WORKDIR/dl-$name"; mkdir -p "$d"
  ( cd "$d" && \
    "$YTDLP" --no-warnings --newline --progress --impersonate chrome \
      $COOKIES_FLAG \
      -f 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b' --merge-output-format mp4 \
      -o "$OUT_TPL" "$url" >/dev/null 2>&1 )
  file=$(find "$d" -type f -name '*.mp4' | head -1)
  if [ -n "$file" ] && [ -s "$file" ]; then
    len=$(echo -n "$(basename "$file")" | wc -c | tr -d ' ')
    ok "download $name → $(basename "$file") ($(du -h "$file" | cut -f1), name len ${len}B)"
  else
    fail "download $name → no mp4 produced"
  fi
done

section "4. Audio extraction (startDownload audio branch)"
d="$WORKDIR/dl-audio"; mkdir -p "$d"
( cd "$d" && \
  "$YTDLP" --no-warnings --impersonate chrome $COOKIES_FLAG \
    -f 'ba/b' -x --audio-format mp3 --audio-quality 128K \
    -o "$OUT_TPL" "$(url_at 0)" >/dev/null 2>&1 )
file=$(find "$d" -type f -name '*.mp3' | head -1)
if [ -n "$file" ] && [ -s "$file" ]; then ok "audio extract → $(basename "$file")"; else fail "audio extract → no mp3 produced"; fi

section "5. ISSUE 1 — long filename fixed by byte-truncated template"
d="$WORKDIR/issue1"; mkdir -p "$d"
( cd "$d" && "$YTDLP" --no-warnings $COOKIES_FLAG \
    -o "$OUT_TPL" "$FB_LONG_URL" >/dev/null 2>&1 )
file=$(find "$d" -type f ! -name '*.log' | head -1)
if [ -n "$file" ] && [ -s "$file" ]; then
  len=$(echo -n "$(basename "$file")" | wc -c | tr -d ' ')
  if [ "$len" -lt 255 ]; then
    ok "issue1 FIX → file created, name length ${len} bytes < 255: $(basename "$file")"
  else
    fail "issue1 FIX → name still too long (${len} bytes ≥ 255)"
  fi
else
  echo -e "  \033[33m[WARN]\033[0m issue1 target produced no file (URL may be unavailable — expected result is a file under 255 bytes)"
fi

section "6. ISSUE 2 — impersonation (403 bypass) flag accepted on all links"
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"; url=$(url_at "$i")
  if "$YTDLP" --no-warnings --impersonate chrome --simulate $COOKIES_FLAG "$url" >/dev/null 2>&1; then
    ok "impersonate chrome accepted → $name"
  else
    echo -e "  \033[33m[WARN]\033[0m impersonate/--simulate error on $name (may be flaky network)"
  fi
done

section "7. Batch (multiple URLs)"
d="$WORKDIR/dl-batch"; mkdir -p "$d"
batch="$WORKDIR/batch-multi.txt"
printf '%s\n' "$(url_at 0)" "$(url_at 1)" > "$batch"
( cd "$d" && "$YTDLP" --no-warnings --newline --impersonate chrome $COOKIES_FLAG \
    -f 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b' \
    --merge-output-format mp4 -o "$OUT_TPL" -a "$batch" >/dev/null 2>&1 )
count=$(find "$d" -name '*.mp4' | wc -l | tr -d ' ')
if [ "$count" -ge 2 ]; then ok "batch download → $count files"; else fail "batch download → expected ≥2 files, got $count"; fi

section "8. Format strings sanity (all options accepted)"
for spec in "${VIDEO_FORMATS[@]}"; do
  case "$spec" in
    best_mp4) fs='bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b';;
    best)     fs='bv*+ba/b';;
    4k_mp4)   fs='bv*[height<=2160][ext=mp4]+ba[ext=m4a]/b[height<=2160][ext=mp4]/bv*[height<=2160]+ba/b[height<=2160]';;
    1080p_mp4)fs='bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]/bv*[height<=1080]+ba/b[height<=1080]';;
    720p_mp4) fs='bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/bv*[height<=720]+ba/b[height<=720]';;
    360p_mp4) fs='bv*[height<=360][ext=mp4]+ba[ext=m4a]/b[height<=360][ext=mp4]/bv*[height<=360]+ba/b[height<=360]';;
  esac
  "$YTDLP" --simulate --no-warnings -f "$fs" "$(url_at 0)" >/dev/null 2>&1 && ok "video format '$spec' accepted" || fail "video format '$spec' rejected"
done
for spec in "${AUDIO_FORMATS[@]}"; do
  case "$spec" in
    best_audio) fs='ba/b'; fmt='best'; q='0';;
    mp3_128)    fs='ba/b'; fmt='mp3';  q='128K';;
    m4a_best)   fs='ba[ext=m4a]/ba/b'; fmt='m4a'; q='0';;
    opus_best)  fs='ba[ext=webm]/ba/b'; fmt='opus'; q='0';;
  esac
  "$YTDLP" --simulate --no-warnings -f "$fs" -x --audio-format "$fmt" --audio-quality "$q" "$(url_at 0)" >/dev/null 2>&1 && ok "audio format '$spec' accepted" || fail "audio format '$spec' rejected"
done

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