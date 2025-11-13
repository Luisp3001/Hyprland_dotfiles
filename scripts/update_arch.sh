#!/bin/bash

# This script updates an Arch Linux system by synchronizing package databases
updates=$(checkupdates 2>/dev/null)

if [ -z "$updates" ]; then
    notify-send -i /home/luisp/Pictures/icon/arch.png " Sistema" " No hay actualizaciones disponibles"
    exit 0
fi

# Muestra la lista en Rofi y pregunta si continuar
choice=$(echo -e "Sí\nNo" | rofi -dmenu -i -p "Actualizaciones disponibles ¿Desea actualizar?

$updates" -theme ~/.config/rofi/launchers/type-6/script_selector.rasi)

if [[ "$choice" == "Sí" ]]; then
    pkexec pacman -Syu --noconfirm
    if [ $? -eq 0 ]; then
        notify-send -i /home/luisp/Pictures/icon/arch.png " Sistema" " Todas las actualizaciones se han instalado correctamente"
    else
        notify-send -i /home/luisp/Pictures/icon/arch.png " Error sistema" " Ocurrió un error durante la actualización del sistema revisar en la terminal"
    fi

else
    notify-send -i /home/luisp/Pictures/icon/arch.png " Actualización cancelada" " El sistema no fue actualizado"
fi
