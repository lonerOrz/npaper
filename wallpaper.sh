#!/usr/bin/env bash

# =============================================================================
# Wallpaper Selector CLI
# =============================================================================
# Author:      loner <lonerOrz@qq.com>
# Version:     1.0.0
# License:     MIT
#
# Description:
#   Wallpaper management tool for any Wayland compositor.
#   Supports image and video wallpapers with awww transition effects.
#   Integrates with mpvpaper for live wallpapers.
#
# Dependencies:
#   Required:
#     - awww                      - Wallpaper daemon with transitions
#     - wlr-randr                 - Monitor detection
#
#   Optional:
#     - mpvpaper                  - Video/live wallpaper support
#     - ffmpeg                    - Thumbnail generation (for QML widget)
#
# Installation (Arch Linux):
#   sudo pacman -S awww wlr-randr mpvpaper ffmpeg
#
# Usage:
#   ./wallpaper_selector.sh --list           - List all wallpapers
#   ./wallpaper_selector.sh --apply <path>   - Apply wallpaper
#   ./wallpaper_selector.sh --help           - Show help message
#
# Supported Formats:
#   Images: JPG, JPEG, PNG, GIF, BMP, TIFF, WEBP
#   Videos: MP4, MKV, MOV, WEBM
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly WALLPAPER_DIRS=(
    "$HOME/Pictures/wallpapers"
)

# awww transition settings
readonly AWWW_TRANSITION_TYPE="fade"
readonly AWWW_TRANSITION_DURATION="0.5"
readonly AWWW_TRANSITION_FPS="60"
readonly AWWW_RESIZE="crop"
readonly AWWW_FILTER="Lanczos3"

# =============================================================================
# Global Variables
# =============================================================================

declare -a WALLPAPER_FILES=()

# =============================================================================
# Collect Wallpapers
# =============================================================================

collect_wallpapers() {
    local -a tmp_files=()
    local dir

    WALLPAPER_FILES=()

    for dir in "${WALLPAPER_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue

        while IFS= read -r -d '' file; do
            tmp_files+=("$file")
        done < <(find -L "$dir" -type f \( \
            -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
            -iname "*.gif" -o -iname "*.bmp" -o -iname "*.tiff" -o \
            -iname "*.webp" -o -iname "*.mp4" -o -iname "*.mkv" -o \
            -iname "*.mov" -o -iname "*.webm" \
        \) -print0 2>/dev/null)
    done

    if (( ${#tmp_files[@]} > 0 )); then
        # Deduplicate while preserving order (by directory sequence)
        mapfile -t WALLPAPER_FILES < <(printf '%s\n' "${tmp_files[@]}" | awk '!seen[$0]++')
    fi
}

# =============================================================================
# Ensure awww Daemon Running
# =============================================================================

ensure_awww() {
    if awww query >/dev/null 2>&1; then
        return
    fi

    awww-daemon --format argb &

    local i
    for ((i = 0; i < 20; i++)); do
        if awww query >/dev/null 2>&1; then
            return
        fi
        sleep 0.05
    done

    echo "Warning: awww daemon may not be running" >&2
}

# =============================================================================
# Apply Image Wallpaper
# =============================================================================

apply_image_wallpaper() {
    local path="$1"

    pkill mpvpaper 2>/dev/null || true
    pkill swaybg 2>/dev/null || true
    pkill hyprpaper 2>/dev/null || true

    ensure_awww

    local monitors
    monitors=$(wlr-randr 2>/dev/null | awk '/^[^[:space:]]+ ".*"/ {print $1}' | paste -sd,) || true

    local awww_cmd=(
        awww img
        --transition-type "$AWWW_TRANSITION_TYPE"
        --transition-duration "$AWWW_TRANSITION_DURATION"
        --transition-fps "$AWWW_TRANSITION_FPS"
        --resize "$AWWW_RESIZE"
        --filter "$AWWW_FILTER"
    )

    if [[ -n "$monitors" ]]; then
        "${awww_cmd[@]}" -o "$monitors" "$path" 2>/dev/null || true
    else
        "${awww_cmd[@]}" "$path" 2>/dev/null || true
    fi
}

# =============================================================================
# Apply Video Wallpaper
# =============================================================================

apply_video_wallpaper() {
    local path="$1"

    if ! command -v mpvpaper >/dev/null 2>&1; then
        echo "Error: mpvpaper not installed" >&2
        exit 1
    fi

    pkill mpvpaper 2>/dev/null || true

    mpvpaper -f -p '*' -o "no-audio loop" "$path"
}

# =============================================================================
# Apply Wallpaper (Auto-detect type)
# =============================================================================

apply_wallpaper() {
    local path="$1"
    local filename
    filename="${path##*/}"

    if [[ "$filename" =~ \.(mp4|mkv|mov|webm)$ ]]; then
        apply_video_wallpaper "$path"
    else
        apply_image_wallpaper "$path"
    fi
}

# =============================================================================
# Commands
# =============================================================================

cmd_list() {
    collect_wallpapers

    local wp
    for wp in "${WALLPAPER_FILES[@]}"; do
        echo "$wp"
    done
}

cmd_apply() {
    local file="$1"

    if [[ -z "$file" ]]; then
        echo "Error: No file specified" >&2
        exit 1
    fi

    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        exit 1
    fi

    apply_wallpaper "$file"

    # Execute config.sh with the wallpaper path if it exists in the same directory
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_script="$script_dir/config.sh"

    if [[ -x "$config_script" ]]; then
        "$config_script" "$file"
    fi
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTION...]

Wallpaper selector for QML widget.

Options:
  --list                    List wallpapers
  --apply <path>            Apply wallpaper
  --help                    Show this help

Supported formats:
  Images: JPG, JPEG, PNG, GIF, BMP, TIFF, WEBP
  Videos: MP4, MKV, MOV, WEBM
EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
    local mode=""
    local apply_path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                show_help
                exit 0
                ;;
            --list)
                mode="list"
                shift
                ;;
            --apply)
                mode="apply"
                shift
                if [[ $# -gt 0 ]]; then
                    apply_path="$1"
                    shift
                fi
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage." >&2
                exit 1
                ;;
        esac
    done

    case "$mode" in
        list)
            cmd_list
            ;;
        apply)
            cmd_apply "$apply_path"
            ;;
        *)
            echo "Error: No command specified. Use --help." >&2
            exit 1
            ;;
    esac
}

main "$@"
