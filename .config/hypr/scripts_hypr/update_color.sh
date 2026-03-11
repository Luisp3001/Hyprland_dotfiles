#!/bin/bash

ruta=$(swww query | grep 'currently displaying' | sed -E 's/.*image: (.*)/\1/')

magick "$ruta" -resize 800x600 ~/.cache/wallpaper.jpg
wal -i "$ruta" 
killall cava 
sleep 1.5 && pkill waybar && hyprctl dispatch exec waybar
hyprctl reload
swaync-client --reload-css
/home/luisp/.config/hypr/scripts_hypr/colors.sh
/home/luisp/.config/hypr/scripts_hypr/update_sddm.sh
notify-send -i /home/luisp/Pictures/icon/arch.png " Sistema" " Colores actualizados."
