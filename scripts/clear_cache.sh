pkexec paccache -r
if [ $? -eq 0 ]; then
    notify-send -i ~/Pictures/icon/arch.png "Sistema" "La caché se ha limpiado correctamente."
else
    notify-send -i ~/Pictures/icon/arch.png "Sistema" "Error al limpiar la caché."
fi
