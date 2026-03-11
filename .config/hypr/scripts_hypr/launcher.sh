#!/usr/bin/env bash

dir="$HOME/.config/rofi/launchers/style-10.rasi"
magick ~/.cache/wallpaper.jpg -blur 0x5 ~/.cache/wallpaper-blur.jpg

## Run
rofi \
    -show drun \
    -theme ${dir}
