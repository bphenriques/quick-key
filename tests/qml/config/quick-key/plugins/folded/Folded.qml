import QtQuick
import qs

Plugin {
  text: Qt.createComponent(Qt.resolvedUrl("Piece.qml")).createObject(this)?.word ?? ""
}
