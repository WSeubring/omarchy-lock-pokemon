import QtQuick

// Ambient motion behind the card contents, one behaviour per Pokémon type.
//
// Hand-rolled rather than QtQuick.Particles: a lock screen wants a dozen slow
// shapes, not a particle system, and this keeps the plugin to plain QtQuick
// with no extra imports. Each shape animates on its own loop with a staggered
// start, so nothing pulses in lockstep.
Item {
  id: root

  // "embers" | "bubbles" | "leaves" | "flakes" | "wisps" | "twinkles" | "none"
  property string kind: "none"
  property color tint: "#ffffff"
  property real intensity: 1.0
  readonly property int count: kind === "none" ? 0 : Math.max(1, Math.round(12 * intensity))

  clip: true
  visible: kind !== "none" && intensity > 0

  Repeater {
    model: root.count

    delegate: Item {
      id: shape
      required property int index

      // Deterministic-per-index jitter would repeat visibly across a row of
      // shapes; a random seed per shape is what makes the drift look natural.
      readonly property real seed: Math.random()
      readonly property real seedB: Math.random()
      readonly property int stagger: Math.round(seed * 6000)

      x: seedB * root.width
      width: 1
      height: 1

      Rectangle {
        id: dot
        anchors.centerIn: parent
        width: {
          switch (root.kind) {
            case "embers": return 2 + shape.seed * 2
            case "bubbles": return 5 + shape.seed * 7
            case "leaves": return 5 + shape.seed * 3
            case "flakes": return 2 + shape.seed * 2
            case "wisps": return 26 + shape.seed * 26
            case "twinkles": return 2 + shape.seed * 2
          }
          return 3
        }
        height: root.kind === "leaves" ? Math.max(2, width * 0.6) : width
        radius: root.kind === "leaves" ? Math.max(1, height / 2) : width / 2
        color: root.kind === "bubbles" ? "transparent" : root.tint
        border.width: root.kind === "bubbles" ? 1 : 0
        border.color: root.tint
        opacity: 0
        rotation: root.kind === "leaves" ? shape.seed * 90 : 0
      }

      // Rising: embers and bubbles start below the frame and leave through the
      // top, fading in and out so they never pop.
      SequentialAnimation {
        running: root.visible && (root.kind === "embers" || root.kind === "bubbles")
        loops: Animation.Infinite
        PauseAnimation { duration: shape.stagger }
        ParallelAnimation {
          NumberAnimation {
            target: shape; property: "y"
            from: root.height + 10; to: -20
            duration: root.kind === "bubbles" ? 9000 + shape.seed * 6000 : 5000 + shape.seed * 4000
            easing.type: Easing.Linear
          }
          NumberAnimation {
            target: shape; property: "x"
            to: Math.max(0, Math.min(root.width, shape.x + (shape.seed - 0.5) * 90))
            duration: root.kind === "bubbles" ? 9000 : 5000
            easing.type: Easing.InOutSine
          }
          SequentialAnimation {
            NumberAnimation { target: dot; property: "opacity"; to: root.kind === "bubbles" ? 0.35 : 0.75; duration: 900 }
            PauseAnimation { duration: root.kind === "bubbles" ? 6500 : 3200 }
            NumberAnimation { target: dot; property: "opacity"; to: 0; duration: 900 }
          }
        }
      }

      // Falling: leaves sway on the way down, flakes drop straight.
      SequentialAnimation {
        running: root.visible && (root.kind === "leaves" || root.kind === "flakes")
        loops: Animation.Infinite
        PauseAnimation { duration: shape.stagger }
        ParallelAnimation {
          NumberAnimation {
            target: shape; property: "y"
            from: -20; to: root.height + 10
            duration: root.kind === "leaves" ? 8000 + shape.seed * 5000 : 11000 + shape.seed * 6000
          }
          NumberAnimation {
            target: shape; property: "x"
            to: Math.max(0, Math.min(root.width, shape.x + (shape.seed - 0.5) * (root.kind === "leaves" ? 140 : 40)))
            duration: root.kind === "leaves" ? 8000 : 11000
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            target: dot; property: "rotation"
            to: dot.rotation + (root.kind === "leaves" ? 200 : 0)
            duration: 8000
          }
          SequentialAnimation {
            NumberAnimation { target: dot; property: "opacity"; to: root.kind === "leaves" ? 0.6 : 0.55; duration: 1200 }
            PauseAnimation { duration: 6000 }
            NumberAnimation { target: dot; property: "opacity"; to: 0; duration: 1200 }
          }
        }
      }

      // Drifting: wisps slide sideways at a fixed height, barely there.
      SequentialAnimation {
        running: root.visible && root.kind === "wisps"
        loops: Animation.Infinite
        PauseAnimation { duration: shape.stagger }
        ScriptAction { script: shape.y = shape.seed * root.height }
        ParallelAnimation {
          NumberAnimation {
            target: shape; property: "x"
            from: -40; to: root.width + 40
            duration: 14000 + shape.seed * 8000
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            target: shape; property: "y"
            to: Math.max(0, Math.min(root.height, shape.y + (shape.seed - 0.5) * 60))
            duration: 14000
            easing.type: Easing.InOutSine
          }
          SequentialAnimation {
            NumberAnimation { target: dot; property: "opacity"; to: 0.13; duration: 2500 }
            PauseAnimation { duration: 8000 }
            NumberAnimation { target: dot; property: "opacity"; to: 0; duration: 2500 }
          }
        }
      }

      // Twinkles hold position and pulse.
      SequentialAnimation {
        running: root.visible && root.kind === "twinkles"
        loops: Animation.Infinite
        ScriptAction { script: shape.y = shape.seed * root.height }
        PauseAnimation { duration: shape.stagger }
        NumberAnimation { target: dot; property: "opacity"; to: 0.85; duration: 700 + shape.seed * 600 }
        NumberAnimation { target: dot; property: "opacity"; to: 0; duration: 900 + shape.seedB * 900 }
        PauseAnimation { duration: 600 + shape.seedB * 2600 }
      }
    }
  }
}
