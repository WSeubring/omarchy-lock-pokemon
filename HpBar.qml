import QtQuick
import qs.Commons

// Battery as a Pokémon HP bar. The lock screen already has a Pokémon standing
// on it; a percentage in a status strip was the least interesting way to show
// the one number that matters on a laptop.
//
// Palette follows the games by default — green, then yellow under half, then
// red under a fifth — because that reading is instant and needs no legend.
// `tint` switches it to a single themed color for anyone who wants the card to
// stay monochrome.
Item {
  id: root

  property real value: 1.0            // 0..1
  property bool charging: false
  property color tint: "transparent"  // set to override the HP palette
  property color trackColor: Color.lock.placeholder
  property color labelColor: Color.lock.placeholder
  property int labelSize: 11
  property int barHeight: 7

  readonly property real clamped: Math.max(0, Math.min(1, value))
  readonly property color fillColor: {
    if (Qt.colorEqual(tint, "transparent")) {
      if (clamped > 0.5) return "#78c850"
      if (clamped > 0.2) return "#f8d030"
      return "#f04040"
    }
    return tint
  }

  implicitHeight: Math.max(barHeight, label.implicitHeight)

  Row {
    anchors.fill: parent
    spacing: 7

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      text: root.charging ? "⚡HP" : "HP"
      color: root.labelColor
      font.family: Style.font.family
      font.pixelSize: root.labelSize
      font.bold: true
      font.letterSpacing: 0.5
    }

    Rectangle {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - label.width - percent.width - parent.spacing * 2
      height: root.barHeight
      radius: height / 2
      color: Qt.rgba(root.trackColor.r, root.trackColor.g, root.trackColor.b, 0.25)

      Rectangle {
        id: fill
        width: Math.max(parent.height, parent.width * root.clamped)
        height: parent.height
        radius: parent.radius
        color: root.fillColor
        // Keeps the charging highlight inside the filled part instead of
        // travelling on across the label and the percentage.
        clip: true

        Behavior on width {
          NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }

        // Charging reads as motion rather than a second glyph: a highlight
        // sweeps the filled part, so a glance tells you it is going up.
        Rectangle {
          id: sweep
          visible: root.charging
          width: 26
          height: parent.height
          radius: parent.radius
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
            GradientStop { position: 1.0; color: "transparent" }
          }

          SequentialAnimation {
            running: sweep.visible
            loops: Animation.Infinite
            NumberAnimation { target: sweep; property: "x"; from: -sweep.width; to: fill.width; duration: 1800; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 900 }
          }
        }
      }
    }

    Text {
      id: percent
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(root.clamped * 100) + "%"
      color: root.labelColor
      font.family: Style.font.family
      font.pixelSize: root.labelSize
    }
  }
}
