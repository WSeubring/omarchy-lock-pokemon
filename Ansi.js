.pragma library

// Converts the truecolor ANSI half-block art that pokemon-colorscripts emits
// into QML rich text. Sprites are drawn as U+2580/U+2584 glyphs carrying a
// foreground and a background color, so each run becomes a <span> with both.
//
// Pure black is the sprite's own "nothing here" color. Painting it would put a
// black slab on the wallpaper, so both black foregrounds and black backgrounds
// are dropped and the blurred background shows through instead.

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/ /g, "&nbsp;")
}

function hex(r, g, b) {
  function pad(value) {
    var clamped = Math.max(0, Math.min(255, Math.round(value)))
    return (clamped < 16 ? "0" : "") + clamped.toString(16)
  }
  return "#" + pad(r) + pad(g) + pad(b)
}

function isBlack(color) {
  return color === "#000000"
}

// Returns rich text for the whole sprite, or "" when there is nothing to draw.
function toRichText(raw, lineHeightPx) {
  var text = String(raw || "")
  if (text.length === 0) return ""

  var lines = text.replace(/\r/g, "").split("\n")
  var html = []

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (i === lines.length - 1 && line.trim().length === 0) continue

    var foreground = ""
    var background = ""
    var runs = []
    var pending = ""

    function flush() {
      if (pending.length === 0) return
      var style = []
      if (foreground.length > 0 && !isBlack(foreground)) style.push("color:" + foreground)
      if (background.length > 0 && !isBlack(background)) style.push("background-color:" + background)
      var body = escapeHtml(pending)
      runs.push(style.length > 0 ? "<span style=\"" + style.join(";") + "\">" + body + "</span>" : body)
      pending = ""
    }

    var index = 0
    while (index < line.length) {
      if (line.charAt(index) === "\x1b" && line.charAt(index + 1) === "[") {
        var end = line.indexOf("m", index)
        if (end < 0) break
        var codes = line.substring(index + 2, end).split(";")
        flush()
        if (codes.length === 1 && (codes[0] === "0" || codes[0] === "")) {
          foreground = ""
          background = ""
        } else if (codes[0] === "38" && codes[1] === "2") {
          foreground = hex(Number(codes[2]), Number(codes[3]), Number(codes[4]))
        } else if (codes[0] === "48" && codes[1] === "2") {
          background = hex(Number(codes[2]), Number(codes[3]), Number(codes[4]))
        }
        index = end + 1
        continue
      }

      pending += line.charAt(index)
      index++
    }

    flush()
    // A fixed line-height keeps the half-blocks touching; the default leading
    // would slice the sprite into stripes.
    html.push("<div style=\"line-height:" + lineHeightPx + "px\">" + (runs.length > 0 ? runs.join("") : "&nbsp;") + "</div>")
  }

  return html.join("")
}
