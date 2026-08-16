import QtQuick

// The shiny moment. Fires once when a shiny sprite lands: eight four-pointed
// stars burst outward from the sprite and fade, then a couple of them keep
// twinkling slowly so the card stays marked for as long as you look at it.
Item {
  id: root

  property bool active: false
  property color tint: "#ffe066"
  property int burstCount: 8

  Repeater {
    model: root.burstCount

    delegate: Item {
      id: star
      required property int index

      readonly property real angle: (index / root.burstCount) * Math.PI * 2 + Math.random() * 0.4
      readonly property real reach: Math.min(root.width, root.height) * (0.35 + Math.random() * 0.3)
      property real travel: 0

      visible: root.active
      x: root.width / 2 + Math.cos(angle) * reach * travel
      y: root.height / 2 + Math.sin(angle) * reach * travel
      width: 1
      height: 1

      // A four-pointed star, drawn as two crossed diamonds so it reads as a
      // sparkle rather than a dot at 10px.
      Item {
        id: glyph
        anchors.centerIn: parent
        width: 11
        height: 11
        opacity: 0
        scale: 0.4

        Rectangle {
          anchors.centerIn: parent
          width: parent.width
          height: 2
          radius: 1
          color: root.tint
        }

        Rectangle {
          anchors.centerIn: parent
          width: 2
          height: parent.height
          radius: 1
          color: root.tint
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.width * 0.7
          height: 2
          radius: 1
          color: root.tint
          rotation: 45
        }

        Rectangle {
          anchors.centerIn: parent
          width: 2
          height: parent.height * 0.7
          radius: 1
          color: root.tint
          rotation: 45
        }
      }

      // Burst: out from the centre, spinning up to full size, then gone.
      // Plays the moment `active` flips true, which is when a shiny sprite has
      // actually landed — the view is reused between locks, so this is a
      // running binding rather than a one-shot on creation.
      SequentialAnimation {
        id: burst
        running: root.active
        PauseAnimation { duration: Math.round(star.index * 45) }
        ParallelAnimation {
          NumberAnimation { target: star; property: "travel"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
          NumberAnimation { target: glyph; property: "scale"; from: 0.4; to: 1.25; duration: 900; easing.type: Easing.OutBack }
          NumberAnimation { target: glyph; property: "rotation"; from: 0; to: 90; duration: 900 }
          SequentialAnimation {
            NumberAnimation { target: glyph; property: "opacity"; to: 1; duration: 160 }
            PauseAnimation { duration: 340 }
            NumberAnimation { target: glyph; property: "opacity"; to: 0; duration: 400 }
          }
        }
        // Two of the eight stay behind, twinkling near the sprite.
        ScriptAction { script: if (star.index % 4 === 0) idle.restart() }
      }

      SequentialAnimation {
        id: idle
        running: false
        loops: Animation.Infinite
        PauseAnimation { duration: 900 + star.index * 600 }
        NumberAnimation { target: glyph; property: "opacity"; to: 0.85; duration: 380 }
        NumberAnimation { target: glyph; property: "opacity"; to: 0; duration: 620 }
      }
    }
  }
}
