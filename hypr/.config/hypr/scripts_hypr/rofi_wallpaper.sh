#!/usr/bin/env bash

wall_dir="$HOME/wallpaper" # Directorio de fondos de pantalla
cache_dir="$HOME/.cache/thumbnails/bgselector" # Directorio de caché de miniaturas

mkdir -p "$cache_dir"

# Generar miniaturas
find "$wall_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | while read -r imagen; do
	filename="$(basename "$imagen")"
	thumb="$cache_dir/$filename"
	if [ ! -f "$thumb" ]; then
		magick convert -strip "$imagen" -thumbnail x540^ -gravity center -extent 262x540 "$thumb"
	fi
done

# Listar fondos de pantalla con miniaturas en rofi
wall_selection=$(ls "$wall_dir" | while read -r A; do echo -en "$A\x00icon\x1f$cache_dir/$A\n"; done | rofi -dmenu -config "$HOME/.config/rofi/bgselector.rasi")

# Establecer el fondo de pantalla seleccionado y ejecutar el script de pywal
if [ -n "$wall_selection" ]; then
	swww img "$wall_dir/$wall_selection" -t grow --transition-duration 1 --transition-fps 75
	sleep 0.2
	~/.config/hypr/scripts/./setwall_waypaper.sh
	exit 0
else
	exit 1
fi
