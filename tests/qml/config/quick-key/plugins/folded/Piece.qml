import QtQuick

QtObject {
  required property var plugin

  Component.onCompleted: plugin.text = "from its folder"
}
