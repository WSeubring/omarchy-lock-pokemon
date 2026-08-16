import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Ansi.js" as Ansi

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: Math.round(numberToken("field-width", 381))
  readonly property int fieldHeight: Math.round(numberToken("field-height", 67))
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  // ---------------------------------------------------------------- ricing

  // Clock/date/greeting block above the field and the status strip along the
  // bottom. Everything here is read-only chrome: it never gates unlocking, so
  // a source that fails to resolve just leaves its slot empty.
  //
  // Every knob below reads `[lock]` in shell.toml through Color.shellValues,
  // which is the theme's generated file with ~/.config/omarchy/shell.toml
  // merged on top. So a theme ships its own look via
  // themes/<slug>/shell.lock.toml, and the machine-level file overrides any
  // single key without touching the theme. Unset keys fall back to the
  // palette-derived defaults, so the plugin still looks right under a theme
  // that says nothing about the lock screen.

  function token(key, fallback) {
    var value = Color.shellValues["lock." + key]
    if (value === undefined || value === null) return fallback
    var text = String(value).trim()
    return text.length > 0 ? text : fallback
  }

  function numberToken(key, fallback) {
    var raw = token(key, "")
    if (raw.length === 0) return fallback
    var value = Number(raw)
    return isFinite(value) ? value : fallback
  }

  function flagToken(key, fallback) {
    var value = token(key, "").toLowerCase()
    if (value.length === 0) return fallback
    if (["1", "true", "yes", "on", "show", "shown", "visible"].indexOf(value) >= 0) return true
    if (["0", "false", "no", "off", "hide", "hidden"].indexOf(value) >= 0) return false
    return fallback
  }

  // Accepts the same values as any other shell color token: a hex string, a
  // role name (text/accent/background), or a `section.key` reference. Text
  // can't be painted with a gradient, so pointing one of these at
  // `hyprland.active-border` takes the gradient's first stop.
  function colorToken(key, fallback) {
    var value = token(key, "")
    if (value.length === 0) return fallback
    var resolved = Border.resolveValueRef(value)
    var stops = resolved.split(/\s+/).filter(part => part.length > 0 && !part.match(/^-?\d+(\.\d+)?deg$/))
    return Border.cssColor(stops.length > 0 ? stops[0] : resolved, 1.0)
  }

  readonly property bool showClock: flagToken("clock", true)
  readonly property bool showDate: flagToken("date", true)
  readonly property bool showGreeting: flagToken("greeting", true)
  readonly property bool showStatus: flagToken("status", true)
  // Space-separated list, so a theme can drop or reorder the strip's entries:
  // `status-items = "battery keyboard"`.
  readonly property string statusItems: token("status-items", "battery uptime keyboard")

  function statusEnabled(name) {
    return statusItems.toLowerCase().split(/[\s,]+/).indexOf(name) >= 0
  }

  readonly property int clockFontSize: Math.round(numberToken("clock-size", Style.font.displayLarge * 3.0))
  readonly property int dateFontSize: Math.round(numberToken("date-size", Style.font.heading * 1.15))
  readonly property int greetingFontSize: Math.round(numberToken("greeting-size", Style.font.title))
  readonly property int statusFontSize: Math.round(numberToken("status-size", Style.font.subtitle))

  readonly property color clockColor: colorToken("clock-color", Color.lock.text)
  readonly property color dateColor: colorToken("date-color", Color.lock.placeholder)
  readonly property color greetingColor: colorToken("greeting-color", Color.lock.text)
  readonly property color statusColor: colorToken("status-color", Color.lock.placeholder)

  readonly property string clockFormat: token("clock-format", "HH:mm")
  readonly property string dateFormat: token("date-format", "dddd d MMMM")

  // Wallpaper treatment. blur 0 leaves the background sharp; scrim-alpha 0
  // drops the darkening wash entirely.
  readonly property real backgroundBlur: Math.max(0, Math.min(1, numberToken("blur", 1.0)))
  readonly property real scrimAlpha: Math.max(0, Math.min(1, numberToken("scrim-alpha", 0.55)))

  // Pokémon sprite above the clock, drawn from pokemon-colorscripts' ANSI art.
  // `pokemon-name` pins one; unset picks a fresh random one per lock, from
  // `pokemon-generations` (the tool's own 1-8 range/list syntax) when set.
  readonly property bool showPokemon: flagToken("pokemon", true)
  readonly property bool pokemonShiny: flagToken("pokemon-shiny", false)
  readonly property int pokemonFontSize: Math.round(numberToken("pokemon-size", 11))
  readonly property string pokemonName: token("pokemon-name", "")
  readonly property string pokemonGenerations: token("pokemon-generations", "")
  // The sprite's own name, shown under it and usable in the greeting via
  // {pokemon}. Empty until the process lands, or when nothing was drawn.
  property string pokemonLabel: ""
  property string pokemonArt: ""
  property int pokemonLines: 0

  // Sprites run 15-30 rows depending on the Pokémon, and the column has to
  // clear the clock block and the field. Shrink the glyph until the tallest
  // sprite fits rather than letting it clip off the top of the screen.
  readonly property real pokemonSpaceAbove: {
    var textBlock = (showClock ? clockFontSize * 1.25 : 0)
      + (showDate ? dateFontSize * 1.7 : 0)
      + (showGreeting ? greetingFontSize * 2.8 : 0)
      + (pokemonLabel.length > 0 ? statusFontSize * 2.4 : 0)
    // The 0.08 term mirrors the column's bottom margin; the flat 32 keeps the
    // tallest sprites clear of the screen edge.
    return Math.max(0, root.height / 2 - fieldHeight / 2 - textBlock - Math.round(root.height * 0.08) - 32)
  }
  readonly property int fittedPokemonFontSize: pokemonLines > 0
    ? Math.max(4, Math.min(pokemonFontSize, Math.floor(pokemonSpaceAbove / pokemonLines)))
    : pokemonFontSize

  property var currentTime: new Date()
  property string fullName: ""
  property string keyboardLayout: ""
  property real uptimeSeconds: 0

  readonly property string clockText: Qt.formatDateTime(currentTime, clockFormat)
  readonly property string dateText: Qt.formatDateTime(currentTime, dateFormat)
  // `greeting-text` takes a literal line, with {name} substituted; unset, the
  // greeting follows the clock.
  readonly property string greetingText: {
    var custom = token("greeting-text", "")
    if (custom.length > 0) return custom.replace("{name}", fullName).replace("{pokemon}", pokemonLabel)
    var hour = currentTime.getHours()
    var part = hour < 6 ? "Still up" : hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    return fullName.length > 0 ? part + ", " + fullName : part
  }
  readonly property string uptimeText: {
    if (uptimeSeconds <= 0) return ""
    var total = Math.floor(uptimeSeconds / 60)
    var days = Math.floor(total / 1440)
    var hours = Math.floor((total % 1440) / 60)
    var minutes = total % 60
    if (days > 0) return days + "d " + hours + "h up"
    if (hours > 0) return hours + "h " + minutes + "m up"
    return minutes + "m up"
  }
  readonly property var batteryDevice: UPower.displayDevice
  readonly property bool batteryPresent: !!(batteryDevice && batteryDevice.isPresent)
  readonly property bool batteryCharging: batteryPresent && batteryDevice.state === UPowerDeviceState.Charging
  readonly property int batteryPercent: batteryPresent ? Math.round(batteryDevice.percentage * 100) : 0
  readonly property string batteryText: batteryPresent
    ? (batteryCharging ? "󰂄 " : "󰁹 ") + batteryPercent + "%"
    : ""

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function refreshChrome() {
    currentTime = new Date()
    uptimeFile.reload()
    if (!keyboardProc.running) keyboardProc.running = true
  }

  // A new sprite per lock, not per minute — it should feel like a greeting,
  // not a slideshow.
  function drawPokemon() {
    if (!showPokemon) { pokemonLabel = ""; pokemonArt = ""; return }
    if (!pokemonProc.running) pokemonProc.running = true
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onFailedAttemptsChanged: {
    if (failedAttempts > 0) shakeAnimation.restart()
  }
  Component.onCompleted: {
    syncPasswordText()
    refreshChrome()
    drawPokemon()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onShowPokemonChanged: drawPokemon()
  onLoadBackgroundChanged: {
    // loadBackground tracks "this surface is actually on screen", so it is the
    // signal that a fresh lock (or preview) just started.
    if (loadBackground) drawPokemon()
  }

  // One second while visible: the clock is the reason, everything else here
  // rides along on the slower timer below.
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.currentTime = new Date()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshChrome()
  }

  // GECOS full name, falling back to the login name. Nothing downstream
  // depends on it, so a missing entry just shortens the greeting.
  Process {
    id: nameProc
    running: true
    command: ["bash", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
    stdout: StdioCollector {
      onStreamFinished: {
        // `user-name` in [lock] wins: GECOS is empty on plenty of installs and
        // the login name rarely reads like a person.
        var override = root.token("user-name", "")
        if (override.length > 0) { root.fullName = override; return }
        var value = String(text).trim()
        var name = value.length > 0 ? value.split(" ")[0] : String(Quickshell.env("USER") || "")
        root.fullName = name.length > 0 ? name.charAt(0).toUpperCase() + name.slice(1) : ""
      }
    }
  }

  Process {
    id: keyboardProc
    command: ["bash", "-c", "hyprctl -j devices | jq -r '[.keyboards[] | select(.main)][0].active_keymap // empty'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var value = String(text).trim()
        if (value.length === 0) { root.keyboardLayout = ""; return }
        // "English (US)" -> "us"; anything without a parenthesised code keeps
        // the first word so an exotic layout still reads as something.
        var match = value.match(/\(([^)]+)\)/)
        var code = match ? match[1] : value
        root.keyboardLayout = code.split(",")[0].trim().toLowerCase().substring(0, 8)
      }
    }
  }

  // Prints the chosen name on the first line, then the sprite. Absent binary,
  // unknown name or a failed draw all end the same way: no sprite, no error.
  Process {
    id: pokemonProc
    // pokemon-colorscripts prints the name on its own first line, then the
    // sprite, which is exactly the split this parses.
    command: ["bash", "-c",
      "command -v pokemon-colorscripts >/dev/null || exit 0; " +
      "if [ -n \"$POKEMON_NAME\" ]; then " +
      "  exec pokemon-colorscripts -n \"$POKEMON_NAME\" $POKEMON_FLAGS; " +
      "fi; " +
      "exec pokemon-colorscripts -r $POKEMON_GENERATIONS $POKEMON_FLAGS"
    ]
    environment: ({
      POKEMON_NAME: root.pokemonName,
      POKEMON_GENERATIONS: root.pokemonGenerations,
      POKEMON_FLAGS: root.pokemonShiny ? "--shiny" : ""
    })
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = String(text).split("\n")
        if (lines.length < 2) { root.pokemonLabel = ""; root.pokemonArt = ""; return }
        var name = lines.shift().trim()
        root.pokemonLabel = name.length > 0 ? name.charAt(0).toUpperCase() + name.slice(1) : ""
        // Count first so fittedPokemonFontSize is settled before the art is
        // rendered at that size.
        root.pokemonLines = lines.filter(line => line.trim().length > 0).length
        root.pokemonArt = Ansi.toRichText(lines.join("\n"), root.fittedPokemonFontSize)
      }
    }
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    watchChanges: false
    printErrors: false
    onLoaded: {
      var first = String(text()).trim().split(" ")[0]
      var seconds = Number(first)
      root.uptimeSeconds = isFinite(seconds) ? seconds : 0
    }
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready && root.backgroundBlur > 0
      blur: root.backgroundBlur
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    // Vertical scrim: darkest at the top and bottom edges where the clock and
    // the status strip sit, so light wallpapers keep the text readable.
    Rectangle {
      anchors.fill: parent
      visible: root.scrimAlpha > 0
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, root.scrimAlpha) }
        GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, root.scrimAlpha * 0.45) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, root.scrimAlpha * 1.1) }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // Clock, date and greeting, hung above the password field so the three
    // blocks read as one centered column.
    Column {
      id: clockColumn
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: inputField.top
      anchors.bottomMargin: Math.round(root.height * 0.08)
      spacing: 6

      // Sprite drawn as rich text: one <span> per colored half-block run, at a
      // fixed line height so the blocks stack seamlessly. Rich text line
      // metrics vary per font, so the final fit is done by scaling the
      // rendered item down to whatever room is left above the clock.
      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showPokemon && root.pokemonArt.length > 0
        implicitWidth: sprite.implicitWidth * sprite.scale
        implicitHeight: sprite.implicitHeight * sprite.scale + 8

        Text {
          id: sprite
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.pokemonArt
          textFormat: Text.RichText
          horizontalAlignment: Text.AlignHCenter
          font.family: Style.font.family
          font.pixelSize: root.fittedPokemonFontSize
          transformOrigin: Item.Top
          scale: implicitHeight > 0 ? Math.min(1, root.pokemonSpaceAbove / implicitHeight) : 1
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showPokemon && root.pokemonLabel.length > 0 && root.flagToken("pokemon-label", true)
        text: root.pokemonLabel
        color: root.statusColor
        font.family: Style.font.family
        font.pixelSize: root.statusFontSize
        bottomPadding: 10
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showClock
        text: root.clockText
        color: root.clockColor
        font.family: Style.font.family
        font.pixelSize: root.clockFontSize
        font.weight: Font.Light
        font.letterSpacing: -2
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showDate
        text: root.dateText
        color: root.dateColor
        font.family: Style.font.family
        font.pixelSize: root.dateFontSize
      }

      Item { width: 1; height: 10; visible: root.showGreeting }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showGreeting
        text: root.greetingText
        color: root.greetingColor
        font.family: Style.font.family
        font.pixelSize: root.greetingFontSize
        opacity: 0.85
      }
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: shakeOffset
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      // Wrong password: a short lateral shake instead of only swapping the
      // border to the error color, so the failure registers peripherally.
      property real shakeOffset: 0

      SequentialAnimation {
        id: shakeAnimation
        loops: 2
        NumberAnimation { target: inputField; property: "shakeOffset"; to: -14; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: inputField; property: "shakeOffset"; to: 14; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: inputField; property: "shakeOffset"; to: 0; duration: 55; easing.type: Easing.InQuad }
      }

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "●"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    // Status strip: battery, uptime, keyboard layout. Each entry drops out of
    // the row when its source has nothing to say (no battery on a desktop, a
    // Hyprland that won't name the layout).
    Row {
      visible: root.showStatus
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(root.numberToken("status-margin", 48))
      spacing: Math.round(root.numberToken("status-gap", 26))

      Text {
        visible: root.statusEnabled("battery") && root.batteryText.length > 0
        text: root.batteryText
        color: root.statusColor
        font.family: Style.font.family
        font.pixelSize: root.statusFontSize
      }

      Text {
        visible: root.statusEnabled("uptime") && root.uptimeText.length > 0
        text: "󰅐 " + root.uptimeText
        color: root.statusColor
        font.family: Style.font.family
        font.pixelSize: root.statusFontSize
      }

      Text {
        visible: root.statusEnabled("keyboard") && root.keyboardLayout.length > 0
        text: "󰌌 " + root.keyboardLayout
        color: root.statusColor
        font.family: Style.font.family
        font.pixelSize: root.statusFontSize
      }
    }
  }
}
