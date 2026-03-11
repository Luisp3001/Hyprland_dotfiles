#!/bin/bash
SRC_DIR="$HOME/dotfiles/wallpaper"
CACHE_DIR="$HOME/.cache/wallpaper"

mkdir -p "$CACHE_DIR"

for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp}; do
    [ -f "$img" ] || continue
    filename=$(basename "$img")
    
    if [ ! -f "$CACHE_DIR/$filename" ]; then
        magick "$img" -resize "400x400^" -gravity center -crop 400x400+0+0 +repage "$CACHE_DIR/$filename"
        echo "Generated thumbnail: $filename"
    fi
done

for vid in "$SRC_DIR"/*.{mp4,mkv,mov,webm}; do
    [ -f "$vid" ] || continue
    filename=$(basename "$vid")
    
    # We prefix videos with 000_ in the QML logic so it knows it is a video
    if [ ! -f "$CACHE_DIR/000_$filename.jpg" ]; then
        ffmpeg -i "$vid" -ss 00:00:01.000 -vframes 1 -vf "scale=400:400:force_original_aspect_ratio=increase,crop=400:400" "$CACHE_DIR/000_$filename.jpg" -y
        echo "Generated thumbnail: 000_$filename.jpg"
    fi
done
