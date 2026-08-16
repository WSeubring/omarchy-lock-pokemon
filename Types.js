.pragma library

// Type -> accent color and ambient behaviour. Colors are the long-standing
// community type palette, which reads as "that's a fire type" without a legend.
//
// Every type has its own effect — no two share one, so a glance at the card
// tells you what you are looking at even before you read the name. `effect`
// names a behaviour in Effects.js. `bob` floats the sprite, `flicker` pulses
// the card edge and `tremor` gives the card an occasional earthquake jolt;
// those ride on top of the type's own weather.

var TABLE = {
  normal:   { color: "#a8a77a", effect: "motes" },
  fire:     { color: "#ee8130", effect: "embers" },
  water:    { color: "#6390f0", effect: "bubbles" },
  electric: { color: "#f7d02c", effect: "strikes", flicker: true },
  grass:    { color: "#7ac74c", effect: "leaves" },
  ice:      { color: "#96d9d6", effect: "flakes" },
  fighting: { color: "#c22e28", effect: "impact" },
  poison:   { color: "#a33ea1", effect: "smog" },
  ground:   { color: "#e2bf65", effect: "grit", tremor: true },
  flying:   { color: "#a98ff3", effect: "gusts", bob: true },
  psychic:  { color: "#f95587", effect: "ripples" },
  bug:      { color: "#a6b91a", effect: "flit" },
  rock:     { color: "#b6a136", effect: "rubble" },
  ghost:    { color: "#735797", effect: "wisps" },
  dragon:   { color: "#6f35fc", effect: "vortex" },
  dark:     { color: "#705746", effect: "gloom" },
  steel:    { color: "#b7b7ce", effect: "plates" },
  fairy:    { color: "#d685ad", effect: "twinkles" }
}

function entry(name) {
  return TABLE[String(name || "").toLowerCase()] || null
}

function color(name, fallback) {
  var found = entry(name)
  return found ? found.color : fallback
}

// The primary type owns the ambient effect.
function effect(types) {
  var primary = entry(types && types.length > 0 ? types[0] : "")
  return primary ? primary.effect : "none"
}

// A dual type layers its second effect underneath the first at a lower
// density. Returns "none" when there is no second type, when it brings no
// motion of its own, or when both types would run the same effect — Gengar
// (ghost/poison) gets wisps and bubbles, but a hypothetical water/water would
// just get louder water.
function secondaryEffect(types) {
  if (!types || types.length < 2) return "none"
  var second = entry(types[1])
  if (!second || second.effect === "none") return "none"
  return second.effect === effect(types) ? "none" : second.effect
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
