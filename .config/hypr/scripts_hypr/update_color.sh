#!/bin/bash

if [ -n "$1" ]; then
    ruta="$1"
else
    # Fallback to current swww wallpaper if no argument provided
    ruta=$(swww query | grep 'currently displaying' | tail -n 1 | sed -E 's/.*image: (.*)/\1/')
fi

if [ -z "$ruta" ]; then
    echo "No wallpaper found to extract colors"
    exit 1
fi

# Resize and save as jpg (using [0] to extract first frame in case it's a gif)
magick "${ruta}[0]" -resize 800x600 ~/.cache/wallpaper.jpg

# We pass $ruta to wal so it uses the full quality image
wal --backend colorz -q -i "$ruta" -n

/home/luisp/.config/hypr/scripts_hypr/colors.sh
/home/luisp/.config/hypr/scripts_hypr/update_sddm.sh
notify-send -i /home/luisp/Pictures/icon/arch.png " Sistema" " Colores actualizados."
