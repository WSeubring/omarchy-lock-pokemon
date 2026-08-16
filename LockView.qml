import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Ansi.js" as Ansi
import "Types.js" as Types

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
  readonly property int outlineThickness: 3
  readonly property int fieldHeight: Math.round(numberToken("field-height", 60))
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

  // ------------------------------------------------------------ theme tokens

  // Every knob reads `[lock]` in shell.toml through Color.shellValues, which is
  // the theme's generated file with ~/.config/omarchy/shell.toml merged on top.
  // A theme ships its look via themes/<slug>/shell.lock.toml; the machine-level
  // file overrides any single key. Unset keys fall back to palette-derived
  // defaults, so this still looks right under a theme that says nothing about
  // the lock screen.

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
  // can't be painted with a gradient, so a token pointing at one takes its
  // first stop.
  function colorToken(key, fallback) {
    var value = token(key, "")
    if (value.length === 0) return fallback
    return firstColor(Border.resolveValueRef(value), fallback)
  }

  function firstColor(raw, fallback) {
    var stops = String(raw).split(/\s+/).filter(part => part.length > 0 && !part.match(/^-?\d+(\.\d+)?deg$/))
    return stops.length > 0 ? Border.cssColor(stops[0], 1.0) : fallback
  }

  // Border spec from a raw color/gradient string, for the two surfaces whose
  // border can come from the Pokémon's types instead of the theme.
  function specFrom(raw, fallbackColor, width, opacity) {
    var resolved = Border.borderValue(String(raw), fallbackColor, opacity === undefined ? 1.0 : opacity, "")
    return Border.withWidth({ color: resolved.color, gradient: resolved.gradient }, width)
  }

  readonly property bool showClock: flagToken("clock", true)
  readonly property bool showDate: flagToken("date", true)
  readonly property bool showGreeting: flagToken("greeting", true)
  readonly property bool showStatus: flagToken("status", true)
  // Space-separated list, so a theme can drop or reorder the strip's entries:
  // `status-items = "battery keyboard"`.
  // Empty by default: the battery lives in the HP bar now, and uptime and
  // keyboard layout were noise on a lock screen. Any of them can be switched
  // back on: `status-items = "uptime keyboard"`.
  readonly property string statusItems: token("status-items", "")

  function statusEnabled(name) {
    // `battery-style = "text"` puts the battery back in the strip without
    // needing status-items spelled out as well.
    if (name === "battery" && batteryStyle === "text") return true
    return statusItems.toLowerCase().split(/[\s,]+/).indexOf(name) >= 0
  }

  readonly property int clockFontSize: Math.round(numberToken("clock-size", Style.font.displayLarge * 2.4))
  readonly property int dateFontSize: Math.round(numberToken("date-size", Style.font.heading))
  readonly property int greetingFontSize: Math.round(numberToken("greeting-size", Style.font.title))
  readonly property int statusFontSize: Math.round(numberToken("status-size", Style.font.bodySmall))

  readonly property color dateColor: colorToken("date-color", Color.lock.placeholder)
  readonly property color greetingColor: colorToken("greeting-color", Color.lock.text)
  readonly property color statusColor: colorToken("status-color", Color.lock.placeholder)
  // The clock defaults to the type accent, which is the one place the Pokémon
  // reaches into the type scale rather than sitting beside it.
  readonly property color clockColor: colorToken("clock-color", accentColor)

  readonly property string clockFormat: token("clock-format", "HH:mm")
  readonly property string dateFormat: token("date-format", "dddd d MMMM")

  // Wallpaper treatment. blur 0 leaves the background sharp; scrim-alpha 0
  // drops the darkening wash entirely.
  readonly property real backgroundBlur: Math.max(0, Math.min(1, numberToken("blur", 1.0)))
  readonly property real scrimAlpha: Math.max(0, Math.min(1, numberToken("scrim-alpha", 0.5)))

  // The card. Width follows the screen until it hits the cap, so this reads the
  // same on a laptop panel and an ultrawide.
  readonly property int cardWidth: Math.round(numberToken("card-width", Math.min(720, root.width * 0.55)))
  readonly property int cardPadding: Math.round(numberToken("card-padding", 30))
  readonly property real cardAlpha: Math.max(0, Math.min(1, numberToken("card-alpha", 0.82)))

  // How the pieces are arranged:
  //   card        everything inside one card
  //   clock-above the clock and date sit on the wallpaper above the card
  //   hero        clock anchored high on the screen, compact card below it
  //   ghost       oversized clock as a watermark behind the card
  //   corner      small muted clock in the screen's top corner
  readonly property string layoutMode: token("layout", "card").toLowerCase()
  readonly property bool clockInCard: layoutMode === "card"
  // ghost and corner move only the clock; the date stays in the card so it
  // still has a headline of its own.
  readonly property bool dateInCard: layoutMode === "card" || layoutMode === "ghost" || layoutMode === "corner"

  // A wash of the theme (or the Pokémon's type) mixed into the card, so the
  // card belongs to the palette instead of being a neutral grey box on top of
  // it. `tint-source` picks which color does the tinting.
  readonly property real cardTint: Math.max(0, Math.min(1, numberToken("card-tint", 0.12)))
  readonly property color tintColor: token("tint-source", "theme").toLowerCase() === "type" ? accentColor : Color.accent
  readonly property color cardBase: Qt.tint(Color.lock.background,
    Qt.rgba(tintColor.r, tintColor.g, tintColor.b, cardTint))
  readonly property color cardColor: Qt.rgba(cardBase.r, cardBase.g, cardBase.b, cardAlpha)
  // Halo of the same color bled out behind the card. Ties the card to the
  // wallpaper without a hard edge.
  readonly property real cardGlow: Math.max(0, Math.min(1, numberToken("card-glow", 0.0)))

  // The wash over the wallpaper. Defaults to the theme's own background rather
  // than black, which is what keeps light themes from looking bruised.
  readonly property color scrimColor: colorToken("scrim-color", Color.background)

  // ---------------------------------------------------------------- Pokémon

  readonly property bool showPokemon: flagToken("pokemon", true)
  readonly property bool showPokemonLabel: flagToken("pokemon-label", true)
  readonly property bool pokemonShiny: flagToken("pokemon-shiny", false)
  readonly property int pokemonFontSize: Math.round(numberToken("pokemon-size", 12))
  readonly property int pokemonHeight: Math.round(numberToken("pokemon-height", 170))
  readonly property string pokemonName: token("pokemon-name", "")
  readonly property string pokemonGenerations: token("pokemon-generations", "")

  // Type-driven chrome: `pokemon-types` colors the clock, glow and borders from
  // the Pokémon's types; `pokemon-effects` adds the ambient motion that goes
  // with the primary type.
  readonly property bool typeAccents: flagToken("pokemon-types", true)
  readonly property bool typeEffects: flagToken("pokemon-effects", true)
  readonly property real effectIntensity: Math.max(0, Math.min(2, numberToken("effect-intensity", 1.0)))
  // Each effect ships three takes (see Effects.js). `effect-variant` picks one
  // for every type; `effect-variant-<kind>` overrides it for a single effect,
  // e.g. `effect-variant-embers = 3`.
  readonly property int effectVariant: variantFor(ambientKind)
  readonly property int secondaryVariant: variantFor(secondaryKind)

  function variantFor(kind) {
    var perKind = numberToken("effect-variant-" + kind, 0)
    if (perKind >= 1) return Math.round(perKind)
    return Math.round(numberToken("effect-variant", 1))
  }

  property string pokemonLabel: ""
  property string pokemonArt: ""
  property var pokemonTypes: []
  property var typeTable: ({})

  readonly property color themeAccent: firstColor(Border.resolveValueRef(token("border", "hyprland.active-border")), Color.lock.borderActive)
  readonly property color accentColor: typeAccents && pokemonTypes.length > 0
    ? Types.color(pokemonTypes[0], themeAccent)
    : themeAccent
  readonly property string typeGradient: typeAccents && pokemonTypes.length > 0
    ? Types.gradient(pokemonTypes, "")
    : ""
  readonly property string typeLabel: Types.label(pokemonTypes)
  // `effect-<type>` swaps the behaviour a type uses, e.g.
  // `effect-electric = "strikes"` for lightning bolts instead of sparks.
  function effectFor(typeName, fallback) {
    if (!typeName) return fallback
    return token("effect-" + String(typeName).toLowerCase(), fallback)
  }

  readonly property string ambientKind: typeEffects && pokemonTypes.length > 0
    ? effectFor(pokemonTypes[0], Types.effect(pokemonTypes))
    : "none"
  // A dual type layers its second effect underneath the first, at a lower
  // density so the card reads as one atmosphere rather than two competing
  // weathers. `dual-effects = hide` goes back to primary-only.
  readonly property bool dualEffects: flagToken("dual-effects", true)
  readonly property string secondaryKind: (typeEffects && dualEffects && pokemonTypes.length > 1)
    ? effectFor(pokemonTypes[1], Types.secondaryEffect(pokemonTypes)) : "none"
  readonly property color secondaryAccent: pokemonTypes.length > 1
    ? Types.color(pokemonTypes[1], accentColor) : accentColor
  readonly property real dualStrength: Math.max(0, Math.min(1, numberToken("dual-effect-strength", 0.55)))
  readonly property bool spriteBobs: typeEffects && Types.trait(pokemonTypes, "bob")
  readonly property bool borderFlickers: typeEffects && Types.trait(pokemonTypes, "flicker")
  // Ground types shake the card every few seconds — small enough to register
  // as a rumble rather than a glitch.
  readonly property bool cardTrembles: typeEffects && Types.trait(pokemonTypes, "tremor")

  // -------------------------------------------------------- border emphasis

  // Card and field both carrying a full-strength type gradient gives the eye no
  // ranking, and the card starts reading as a second input. `border-emphasis`
  // picks how the two relate:
  //
  //   even       both borders equal — the original treatment
  //   card-quiet card hairline at low alpha, field keeps the type gradient
  //   soft-card  no card border at all, just fill and a drop shadow
  //   split      card takes the theme's gradient, field takes the type's
  //   state      card hairline; the field thickens and lights up while typing
  readonly property string borderEmphasis: token("border-emphasis", "card-quiet").toLowerCase()

  readonly property real cardBorderWidth: {
    switch (borderEmphasis) {
      case "soft-card": return 0
      case "card-quiet": case "state": return 1
    }
    return 2
  }
  readonly property real cardBorderAlpha: (borderEmphasis === "card-quiet" || borderEmphasis === "state") ? 0.35 : 1.0
  readonly property bool cardHasShadow: borderEmphasis === "soft-card"
  // `split` hands the card the theme's own active-border so the constant
  // (your desktop) and the variable (today's Pokémon) read as different things.
  readonly property string cardBorderSource: borderEmphasis === "split"
    ? Border.resolveValueRef(token("border", "hyprland.active-border"))
    : typeGradient

  readonly property var cardBorderSpec: cardBorderWidth <= 0
    ? Border.none()
    : (cardBorderSource.length > 0
      ? specFrom(cardBorderSource, accentColor, cardBorderWidth, cardBorderAlpha)
      : Border.withWidth(Border.surfaceSpec("lock", "border", Color.lock.border, cardBorderWidth, "border-alpha"), cardBorderWidth))

  // In `state` the field rests as a hairline and grows while it is being used,
  // so the loudest thing on screen is always the thing you are doing.
  property real fieldBorderWidth: outlineThickness
  readonly property real fieldRestWidth: borderEmphasis === "state" ? 1 : outlineThickness
  readonly property real fieldActiveWidth: outlineThickness
  readonly property bool fieldEngaged: passwordInput.activeFocus && (passwordInput.text.length > 0 || authenticatingPassword)
  readonly property real fieldBorderAlpha: borderEmphasis === "state" && !fieldEngaged ? 0.55 : 1.0

  Binding {
    target: root
    property: "fieldBorderWidth"
    value: root.fieldEngaged ? root.fieldActiveWidth : root.fieldRestWidth
  }

  Behavior on fieldBorderWidth {
    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
  }

  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, outlineThickness, "border-alpha")
    : (typeGradient.length > 0
      ? specFrom(typeGradient, accentColor, fieldBorderWidth, fieldBorderAlpha)
      : Border.withWidth(Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, fieldBorderWidth, "border-alpha"), fieldBorderWidth))

  // ------------------------------------------------------------ status strip

  property var currentTime: new Date()
  property string fullName: ""
  property string keyboardLayout: ""
  property real uptimeSeconds: 0

  readonly property string clockText: Qt.formatDateTime(currentTime, clockFormat)
  readonly property string dateText: Qt.formatDateTime(currentTime, dateFormat)
  // `greeting-text` takes a literal line, with {name} and {pokemon}
  // substituted; unset, the greeting follows the clock.
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
  // `battery-style`: hp-bar (a Pokémon HP gauge under the sprite), text (the
  // old status-strip entry), or hide. `hp-colors = theme` swaps the classic
  // green/yellow/red for the theme accent.
  readonly property string batteryStyle: token("battery-style", "hp-bar").toLowerCase()
  readonly property bool hpFollowsTheme: token("hp-colors", "hp").toLowerCase() !== "hp"

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
    if (!showPokemon) { pokemonLabel = ""; pokemonArt = ""; pokemonTypes = []; return }
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

  // name -> [type, type]. Generated from PokéAPI, shipped with the plugin so
  // the lock screen never waits on (or needs) the network.
  FileView {
    id: typeFile
    path: String(Qt.resolvedUrl("types.json")).replace(/^file:\/\//, "")
    watchChanges: false
    printErrors: false
    onLoaded: {
      try { root.typeTable = JSON.parse(text()) } catch (error) { root.typeTable = ({}) }
    }
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

  // pokemon-colorscripts prints the name on its own first line, then the
  // sprite, which is exactly the split this parses.
  Process {
    id: pokemonProc
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
        if (lines.length < 2) { root.pokemonLabel = ""; root.pokemonArt = ""; root.pokemonTypes = []; return }
        var name = lines.shift().trim()
        root.pokemonLabel = name.length > 0 ? name.charAt(0).toUpperCase() + name.slice(1) : ""
        root.pokemonTypes = root.typeTable[name] || []
        root.pokemonArt = Ansi.toRichText(lines.join("\n"), root.pokemonFontSize)
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

    // Even wash rather than a vertical ramp: the card carries the contrast now,
    // so the background only needs to stop competing with it.
    Rectangle {
      anchors.fill: parent
      visible: root.scrimAlpha > 0
      color: Qt.rgba(root.scrimColor.r, root.scrimColor.g, root.scrimColor.b, root.scrimAlpha)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // Borderless cards need something to sit on, or they dissolve into a busy
    // wallpaper. Drawn as a sibling behind the card so the card itself never
    // has to become a layer.
    Rectangle {
      visible: root.cardHasShadow || root.cardGlow > 0
      width: card.width + (root.cardGlow > 0 ? 40 : 0)
      height: card.height + (root.cardGlow > 0 ? 40 : 0)
      x: card.x - (root.cardGlow > 0 ? 20 : 0)
      y: card.y + (root.cardGlow > 0 ? -20 : 10)
      radius: card.radius + (root.cardGlow > 0 ? 20 : 0)
      color: root.cardGlow > 0
        ? Qt.rgba(root.tintColor.r, root.tintColor.g, root.tintColor.b, root.cardGlow * 0.5)
        : Qt.rgba(0, 0, 0, 0.55)
      layer.enabled: visible
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: 1.0
        blurMax: 48
      }
    }

    // Watermark clock: enormous, in the theme's own color at low opacity, with
    // the card sitting over it. The time is there when you look for it and
    // never competes with the field.
    Text {
      visible: root.layoutMode === "ghost" && root.showClock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: card.top
      anchors.bottomMargin: -Math.round(height * 0.34)
      text: root.clockText
      color: root.tintColor
      opacity: Math.max(0, Math.min(1, root.numberToken("ghost-opacity", 0.2)))
      font.family: Style.font.family
      font.pixelSize: Math.round(root.clockFontSize * root.numberToken("ghost-scale", 3.4))
      font.weight: Font.Light
      font.letterSpacing: -8
    }

    // Corner clock: the smallest possible answer, parked where a status bar
    // would be, so the card keeps the whole middle of the screen.
    Text {
      visible: root.layoutMode === "corner" && root.showClock
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: 34
      text: root.clockText
      color: root.dateColor
      font.family: Style.font.family
      font.pixelSize: Math.round(root.dateFontSize * 1.2)
    }

    // Clock outside the card: it stops being one more row in a stack and
    // becomes the thing you read from across the room. `clock-above` keeps it
    // tied to the card; `hero` moves it up into the empty top half.
    Column {
      id: outsideClock
      visible: (root.layoutMode === "clock-above" || root.layoutMode === "hero") && (root.showClock || root.showDate)
      spacing: 2
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: root.layoutMode === "clock-above" ? card.top : undefined
      anchors.bottomMargin: 40
      anchors.verticalCenter: root.layoutMode === "hero" ? parent.verticalCenter : undefined
      anchors.verticalCenterOffset: -Math.round(root.height * 0.24)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showClock
        text: root.clockText
        color: root.clockColor
        font.family: Style.font.family
        // The hero clock is the page's headline, so it gets a size the in-card
        // clock can't take without pushing everything else around.
        font.pixelSize: root.layoutMode === "hero" ? Math.round(root.clockFontSize * 1.9) : Math.round(root.clockFontSize * 1.3)
        font.weight: Font.Light
        font.letterSpacing: -3
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.showDate && !root.dateInCard
        text: root.dateText
        color: root.dateColor
        font.family: Style.font.family
        font.pixelSize: Math.round(root.dateFontSize * 1.15)
      }
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: cardContent.implicitHeight + root.cardPadding * 2
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: shakeOffset + tremorOffset
      // `hero` drops the card below centre to leave the clock the top half.
      anchors.verticalCenterOffset: root.layoutMode === "hero" ? Math.round(root.height * 0.12) : 0
      color: root.cardColor
      borderSpec: root.cardBorderSpec
      radius: Style.cornerRadius > 0 ? Style.cornerRadius + 4 : 0
      clip: true

      // Wrong password: a short lateral shake of the whole card instead of only
      // swapping the field's border color, so the failure registers
      // peripherally.
      property real shakeOffset: 0

      // Earthquake rumble for ground types, on its own offset so it never
      // fights the wrong-password shake.
      property real tremorOffset: 0

      SequentialAnimation {
        running: root.cardTrembles
        loops: Animation.Infinite
        PauseAnimation { duration: 7000 }
        SequentialAnimation {
          loops: 3
          NumberAnimation { target: card; property: "tremorOffset"; to: -2; duration: 55 }
          NumberAnimation { target: card; property: "tremorOffset"; to: 2; duration: 70 }
        }
        NumberAnimation { target: card; property: "tremorOffset"; to: 0; duration: 60 }
      }

      SequentialAnimation {
        id: shakeAnimation
        loops: 2
        NumberAnimation { target: card; property: "shakeOffset"; to: -14; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "shakeOffset"; to: 14; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: card; property: "shakeOffset"; to: 0; duration: 55; easing.type: Easing.InQuad }
      }

      // Ambient type motion, behind everything and clipped to the card.
      // Secondary type first, so the primary's motion sits in front of it.
      Ambient {
        anchors.fill: parent
        kind: root.secondaryKind
        variant: root.secondaryVariant
        tint: root.secondaryAccent
        intensity: root.effectIntensity * root.dualStrength
      }

      Ambient {
        anchors.fill: parent
        kind: root.ambientKind
        variant: root.effectVariant
        tint: root.accentColor
        intensity: root.effectIntensity
      }

      // Electric types flick the card's edge every few seconds.
      Rectangle {
        id: flickerEdge
        anchors.fill: parent
        radius: card.radius
        color: "transparent"
        border.width: 2
        border.color: root.accentColor
        opacity: 0
        visible: root.borderFlickers

        SequentialAnimation {
          running: flickerEdge.visible
          loops: Animation.Infinite
          PauseAnimation { duration: 3400 }
          NumberAnimation { target: flickerEdge; property: "opacity"; to: 0.9; duration: 60 }
          NumberAnimation { target: flickerEdge; property: "opacity"; to: 0.1; duration: 90 }
          NumberAnimation { target: flickerEdge; property: "opacity"; to: 0.7; duration: 70 }
          NumberAnimation { target: flickerEdge; property: "opacity"; to: 0; duration: 500 }
        }
      }

      Column {
        id: cardContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.cardPadding
        spacing: 24

        // Sprite on the left, the time and the greeting on the right.
        Row {
          id: header
          width: parent.width
          spacing: 26

          Item {
            id: spriteSlot
            width: root.showPokemon && root.pokemonArt.length > 0 ? Math.max(sprite.implicitWidth * sprite.scale, 150) : 0
            height: root.showPokemon && root.pokemonArt.length > 0 ? spriteColumn.implicitHeight : 0
            visible: width > 0
            anchors.verticalCenter: parent.verticalCenter

            Column {
              id: spriteColumn
              width: parent.width
              spacing: 6

              Item {
                width: parent.width
                height: sprite.implicitHeight * sprite.scale

                // Soft type-colored glow, sitting under the sprite so it reads
                // as light coming off it rather than a shape of its own.
                Rectangle {
                  anchors.centerIn: sprite
                  width: Math.max(sprite.width * sprite.scale, 120) * 0.9
                  height: width
                  radius: width / 2
                  color: root.accentColor
                  opacity: root.typeAccents ? 0.16 : 0.0
                  layer.enabled: true
                  layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                  }
                }

                // Sprite drawn as rich text: one <span> per colored half-block
                // run, at a fixed line height so the blocks stack seamlessly.
                // Rich-text line metrics vary per font, so the final fit is a
                // scale down to `pokemon-height`.
                Text {
                  id: sprite
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: bobOffset
                  text: root.pokemonArt
                  textFormat: Text.RichText
                  horizontalAlignment: Text.AlignHCenter
                  font.family: Style.font.family
                  font.pixelSize: root.pokemonFontSize
                  transformOrigin: Item.Top
                  scale: implicitHeight > 0 ? Math.min(1, root.pokemonHeight / implicitHeight) : 1

                  // Flying types hover.
                  property real bobOffset: 0
                  SequentialAnimation {
                    running: root.spriteBobs
                    loops: Animation.Infinite
                    NumberAnimation { target: sprite; property: "bobOffset"; to: -7; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { target: sprite; property: "bobOffset"; to: 0; duration: 1600; easing.type: Easing.InOutSine }
                  }
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showPokemonLabel && root.pokemonLabel.length > 0
                text: root.pokemonLabel
                color: Color.lock.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              // Each type in its own color, so a dual type reads as two things
              // rather than one accent standing in for both.
              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showPokemonLabel && root.typeAccents && root.pokemonTypes.length > 0
                spacing: 0

                Repeater {
                  model: root.pokemonTypes

                  delegate: Row {
                    required property int index
                    required property string modelData
                    spacing: 0

                    Text {
                      visible: index > 0
                      text: " / "
                      color: root.statusColor
                      font.family: Style.font.family
                      font.pixelSize: root.statusFontSize
                      opacity: 0.7
                    }

                    Text {
                      text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                      color: Types.color(modelData, root.accentColor)
                      font.family: Style.font.family
                      font.pixelSize: root.statusFontSize
                      opacity: 0.95
                    }
                  }
                }
              }

              // Battery as the Pokémon's HP. Same number a status strip would
              // have printed, in the one visual language this card already
              // speaks.
              HpBar {
                width: parent.width
                visible: root.batteryPresent && root.batteryStyle === "hp-bar"
                value: root.batteryPresent ? root.batteryDevice.percentage : 0
                charging: root.batteryCharging
                tint: root.hpFollowsTheme ? root.accentColor : "transparent"
                trackColor: root.statusColor
                labelColor: root.statusColor
                labelSize: root.statusFontSize
              }
            }
          }

          Column {
            width: parent.width - spriteSlot.width - (spriteSlot.visible ? header.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
              visible: root.showClock && root.clockInCard
              text: root.clockText
              color: root.clockColor
              font.family: Style.font.family
              font.pixelSize: root.clockFontSize
              font.weight: Font.Light
              font.letterSpacing: -2
            }

            Text {
              visible: root.showDate && root.dateInCard
              text: root.dateText
              color: root.dateColor
              font.family: Style.font.family
              font.pixelSize: root.dateFontSize
            }

            Item { width: 1; height: 8; visible: root.showGreeting }

            Text {
              visible: root.showGreeting
              width: parent.width
              text: root.greetingText
              color: root.greetingColor
              font.family: Style.font.family
              font.pixelSize: root.greetingFontSize
              elide: Text.ElideRight
              opacity: 0.85
            }
          }
        }

        BorderSurface {
          id: inputField
          width: parent.width
          height: root.fieldHeight
          color: Qt.rgba(Color.lock.background.r, Color.lock.background.g, Color.lock.background.b, 0.55)
          borderSpec: root.inputBorderSpec
          radius: Style.cornerRadius
          clip: true

          TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.topMargin: inputField.borderTop
            // Reserve the fingerprint icon's width on both sides so the
            // centered dots stay symmetric and never slide under the icon as
            // they grow.
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

          // Fingerprint hint pinned inside the field's right edge when a sensor
          // is enrolled, so the user knows they can touch to unlock instead of
          // typing. Matches hyprlock, which draws its icon in the same spot.
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

        // Card footer: battery, uptime, keyboard layout. Each entry drops out
        // when its source has nothing to say (no battery on a desktop, a
        // Hyprland that won't name the layout).
        Row {
          visible: root.showStatus
          width: parent.width
          spacing: Math.round(root.numberToken("status-gap", 22))

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
  }
}
