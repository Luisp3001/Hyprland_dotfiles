#!/bin/bash
notify-send -i /home/luisp/Pictures/icon/arch.png " Sistema" " Cambiando wallpaper..."

ruta=$(swww query | grep 'currently displaying' | sed -E 's/.*image: (.*)/\1/')

magick "$ruta" -resize 800x600 ~/.cache/wallpaper.jpg
wal -i "$ruta"
killall cava 
sleep 1.5 && pkill waybar && hyprctl dispatch exec waybar
hyprctl reload
swaync-client --reload-css
/home/luisp/.config/hypr/scripts/colors.sh
/home/luisp/.config/hypr/scripts/update_sddm.sh
