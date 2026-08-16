.pragma library

// Type -> accent color and ambient behaviour. Colors are the long-standing
// community type palette, which reads as "that's a fire type" without a legend.
//
// `effect` names a motion in Ambient.qml. `bob` floats the sprite, `flicker`
// pulses the border: those two ride on top of whatever effect the type has, so
// a flying type still gets its primary type's particles.

var TABLE = {
  normal:   { color: "#a8a77a", effect: "none" },
  fire:     { color: "#ee8130", effect: "embers" },
  water:    { color: "#6390f0", effect: "bubbles" },
  electric: { color: "#f7d02c", effect: "none", flicker: true },
  grass:    { color: "#7ac74c", effect: "leaves" },
  ice:      { color: "#96d9d6", effect: "flakes" },
  fighting: { color: "#c22e28", effect: "none" },
  poison:   { color: "#a33ea1", effect: "bubbles" },
  ground:   { color: "#e2bf65", effect: "none" },
  flying:   { color: "#a98ff3", effect: "none", bob: true },
  psychic:  { color: "#f95587", effect: "twinkles" },
  bug:      { color: "#a6b91a", effect: "twinkles" },
  rock:     { color: "#b6a136", effect: "none" },
  ghost:    { color: "#735797", effect: "wisps" },
  dragon:   { color: "#6f35fc", effect: "twinkles" },
  dark:     { color: "#705746", effect: "wisps" },
  steel:    { color: "#b7b7ce", effect: "none" },
  fairy:    { color: "#d685ad", effect: "twinkles" }
}

function entry(name) {
  return TABLE[String(name || "").toLowerCase()] || null
}

function color(name, fallback) {
  var found = entry(name)
  return found ? found.color : fallback
}

// The primary type owns the ambient effect; a secondary type only contributes
// its color to the gradient and its bob/flicker trait.
function effect(types) {
  var primary = entry(types && types.length > 0 ? types[0] : "")
  return primary ? primary.effect : "none"
}

function trait(types, name) {
  if (!types) return false
  for (var i = 0; i < types.length; i++) {
    var found = entry(types[i])
    if (found && found[name]) return true
  }
  return false
}

// Border gradient stops: one color for a single type, both for a dual type.
function gradient(types, fallback) {
  var stops = []
  for (var i = 0; types && i < types.length; i++) {
    var found = entry(types[i])
    if (found) stops.push(found.color)
  }
  if (stops.length === 0) return fallback
  if (stops.length === 1) return stops[0]
  return stops.join(" ") + " 45deg"
}

function label(types) {
  if (!types || types.length === 0) return ""
  return types.map(name => name.charAt(0).toUpperCase() + name.slice(1)).join(" / ")
}
