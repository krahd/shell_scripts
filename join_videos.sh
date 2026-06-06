#!/bin/zsh
# join_videos.sh — normalize and concatenate multiple videos using ffmpeg
# Usage: join_videos.sh [-s SECONDS] [files-pattern] [output-file]
# Requirements: ffmpeg, ffprobe, python3

set -euo pipefail

show_help() {
  cat <<'EOF'
Usage:
  join_videos.zsh [options] [files-pattern] [output-file]

Arguments:
  files-pattern   Glob pattern for input files, e.g. '*.mp4'
                  Default: all common video files in current folder
  output-file     Output filename
                  Default: joined.mp4

Options:
  -s, --separation SECONDS   Length of black/silent gap between videos
                             Default: 0
  -o, --output FILE          Output filename
  -h, --help                 Show this help

Notes:
  If both positional output-file and -o/--output are provided,
  -o/--output takes precedence.

Examples:
  ./join_videos.zsh
  ./join_videos.zsh '*.mp4'
  ./join_videos.zsh '*.mp4' all.mp4
  ./join_videos.zsh -s 0.5 '*.mp4' all.mp4
  ./join_videos.zsh -o final.mp4 '*.mov'
EOF
}

output="joined.mp4"
output_from_option=""
separation="0"
pattern=""
force=0

while (( $# > 0 )); do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -s|--separation)
      if (( $# < 2 )); then
        echo "Error: missing value for $1" >&2
        exit 1
      fi
      separation="$2"
      shift 2
      ;;
    -o|--output)
      if (( $# < 2 )); then
        echo "Error: missing value for $1" >&2
        exit 1
      fi
      output_from_option="$2"
      shift 2
      ;;
    -f|--force)
      force=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      echo "Use -h or --help for usage." >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if (( $# > 0 )); then
  pattern="$1"
  shift
fi

if (( $# > 0 )); then
  output="$1"
  shift
fi

if (( $# > 0 )); then
  echo "Error: too many positional arguments." >&2
  echo "Use -h or --help for usage." >&2
  exit 1
fi

if [[ -n "$output_from_option" ]]; then
  output="$output_from_option"
fi

case "$separation" in
  ''|*[!0-9.]*)
    echo "Error: separation must be a non-negative number." >&2
    exit 1
    ;;
esac

tmpdir="$(mktemp -d)"
listfile="$tmpdir/inputs.txt"

fps=30
width=1920
height=1080
vcodec="libx264"
acodec="aac"
pixfmt="yuv420p"
samplerate="48000"

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

if [[ -n "$pattern" ]]; then
  files=( ${(~)pattern}(N) )
else
  files=(*.(mp4|mov|mkv|avi|m4v|MP4|MOV|MKV|AVI|M4V)(N))
fi

if (( ${#files} == 0 )); then
  echo "No matching video files found." >&2
  exit 1
fi

echo "Found ${#files} video(s):"
printf '  %s\n' "${files[@]}"

first="${files[1]}"

detected_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$first" || true)
detected_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$first" || true)
detected_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$first" || true)

if [[ -n "${detected_width:-}" && -n "${detected_height:-}" ]]; then
  width="$detected_width"
  height="$detected_height"
fi

if [[ -n "${detected_fps:-}" && "$detected_fps" != "0/0" ]]; then
  fps_eval=$(python3 - <<PY
from fractions import Fraction
print(float(Fraction("$detected_fps")))
PY
)
  fps="${fps_eval%.*}"
  [[ -z "$fps" || "$fps" -lt 1 ]] && fps=30
fi

echo "Using output format: ${width}x${height} @ ${fps} fps"
echo "Separation: ${separation}s"
echo "Output: $output"

if [[ -e "$output" && "$force" != "1" ]]; then
  echo "Error: output '$output' already exists. Use -f or --force to overwrite." >&2
  exit 1
fi

i=1
total=${#files}

for f in "${files[@]}"; do
  out="$tmpdir/clip_$i.mp4"

  echo "Normalising: $f"

  ffmpeg -y -i "$f" \
    -vf "scale=${width}:${height}:force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=${fps}" \
    -r "$fps" \
    -c:v "$vcodec" -pix_fmt "$pixfmt" \
    -c:a "$acodec" -ar "$samplerate" -ac 2 \
    "$out"

  print -r -- "file '$out'" >> "$listfile"

  if (( i < total )) && [[ "$separation" != "0" && "$separation" != "0.0" ]]; then
    gap="$tmpdir/gap_$i.mp4"

    echo "Creating ${separation}s gap"

    ffmpeg -y \
      -f lavfi -i "color=c=black:s=${width}x${height}:d=${separation}:r=${fps}" \
      -f lavfi -i "anullsrc=r=${samplerate}:cl=stereo:d=${separation}" \
      -c:v "$vcodec" -pix_fmt "$pixfmt" \
      -c:a "$acodec" -ar "$samplerate" -ac 2 \
      "$gap"

    print -r -- "file '$gap'" >> "$listfile"
  fi

  ((i++))
done

echo "Concatenating into $output"

ffmpeg -y -f concat -safe 0 -i "$listfile" -c copy "$output"

echo "Done: $output"