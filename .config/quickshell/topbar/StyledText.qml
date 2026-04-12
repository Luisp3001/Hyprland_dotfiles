import QtQuick

Text {
  property var walColors: null
  color: walColors ? walColors.colors.color7 : "#abb2bf"
  font.pixelSize: 13
}