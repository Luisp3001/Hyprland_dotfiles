#!/bin/bash
SRC_DIR="$HOME/dotfiles/wallpaper"
CACHE_DIR="$HOME/.cache/wallpaper"

mkdir -p "$CACHE_DIR"

for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp}; do
    [ -f "$img" ] || continue
    filename=$(basename "$img")
    
    if [ ! -f "$CACHE_DIR/$filename" ]; then
        magick "$img" -resize "1100x600" -gravity center "$CACHE_DIR/$filename"
        echo "Generated thumbnail: $filename"
    fi
done

for vid in "$SRC_DIR"/*.{mp4,mkv,mov,webm}; do
    [ -f "$vid" ] || continue
    filename=$(basename "$vid")
    
    # We prefix videos with 000_ in the QML logic so it knows it is a video
    if [ ! -f "$CACHE_DIR/000_$filename.jpg" ]; then
        ffmpeg -i "$vid" -ss 00:00:01.000 -vframes 1 -vf "scale=-1:420" "$CACHE_DIR/000_$filename.jpg" -y
        echo "Generated thumbnail: 000_$filename.jpg"
    fi
done
# --- Cleanup logic ---
echo "Cleaning up old thumbnails..."
for thumb in "$CACHE_DIR"/*; do
    [ -f "$thumb" ] || continue
    thumb_name=$(basename "$thumb")
    
    # Check if it's a video thumbnail (starts with 000_ and ends with .jpg)
    if [[ "$thumb_name" == 000_* ]]; then
        # Remove 000_ prefix and .jpg extension, then check for video extensions
        base_vid="${thumb_name#000_}"
        base_vid="${base_vid%.jpg}"
        found=false
        for ext in mp4 mkv mov webm; do
            if [ -f "$SRC_DIR/$base_vid.$ext" ]; then
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            rm "$thumb"
            echo "Removed old video thumbnail: $thumb_name"
        fi
    else
        # It's a regular image thumbnail
        if [ ! -f "$SRC_DIR/$thumb_name" ]; then
            rm "$thumb"
            echo "Removed old thumbnail: $thumb_name"
        fi
    fi
done
