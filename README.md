# Pokémon Lock Screen

A lock screen for [Omarchy](https://omarchy.org/) 4's Quickshell shell. A random
Pokémon greets you, its types colour the card and stir the air behind it, and
your battery is its HP.

![lock screen](docs/lock.jpg)

It is a clone of the stock `omarchy.lock` plugin, so the session lock, the PAM
flows and the fingerprint handling are upstream code, carried verbatim and
untouched. Everything visible is rewritten.

---

## What it does

**A Pokémon per lock.** Sprites come from
[`pokemon-colorscripts`](https://gitlab.com/phoneybadger/pokemon-colorscripts);
its ANSI half-block art is parsed into rich text at runtime. No binary
installed means no sprite and no error.

**Shinies happen.** Every lock rolls for one at `shiny-odds`, which defaults to
**1 in 128** — rare enough to mean something, common enough to actually see.
Set it to `4096` for the modern games' rate, `8192` for the original, or force
the issue with `pokemon-shiny = "always"`.

![shiny Charizard](docs/shiny.gif)

When one lands it announces itself: eight stars burst out of the sprite, the
glow behind it turns gold and keeps breathing, the name takes a ✦ and a SHINY
tag appears under the types.

**Its types drive the card.** The primary type colours the clock, the glow
behind the sprite and the borders; a dual type turns the borders into a
two-stop gradient and prints each type name in its own colour.

**Eighteen types, eighteen behaviours.** No two types share an effect.

| | | |
|---|---|---|
| ![electric](docs/effects/electric.gif) | ![ice](docs/effects/ice.gif) | ![psychic](docs/effects/psychic.gif) |
| **electric** — lightning strikes | **ice** — drifting flakes | **psychic** — expanding ripples |
| ![rock](docs/effects/rock.gif) | ![dragon](docs/effects/dragon.gif) | ![poison](docs/effects/poison.gif) |
| **rock** — orbiting rubble | **dragon** — inward vortex | **poison** — creeping smog |

The other twelve: embers (fire), bubbles (water), leaves (grass), wisps (ghost),
twinkles (fairy), grit (ground), gusts (flying), shockwave rings (fighting),
flit (bug), dark pools, steel plates and dust motes (normal).

Dual types layer the second type's weather behind the first at 55% density:

| | |
|---|---|
| ![gengar](docs/effects/dual-gengar.gif) | ![venusaur](docs/effects/dual-venusaur.gif) |
| **Gengar** — ghost wisps over poison smog | **Venusaur** — leaves falling through smog |

Three types also carry a trait on top of, or instead of, their weather: flying
hovers the sprite, electric flicks the card edge, ground rumbles the whole card.

**Battery as HP** — optional, on by default.

![hp bar](docs/hp-bar.jpg)

Green above 50%, yellow to 20%, red below, exactly as the games do it, so it
needs no legend. Plugged in, the label becomes `⚡HP` and a highlight sweeps the
fill. `battery-style = "text"` puts a plain percentage in the status strip
instead, `"hide"` drops it entirely, and `hp-colors = "theme"` swaps the game
palette for the theme accent.

---

## It follows your Omarchy theme

The card fill is the active theme's background mixed toward its accent, the wash
over the wallpaper is theme-coloured rather than black, and every piece of text
comes from the theme's own `[lock]` tokens. Switching themes restyles the lock
screen with no per-theme configuration.

| | |
|---|---|
| ![Tokyo Night](docs/themes/tokyo-night.jpg) | ![Rosé Pine](docs/themes/rose-pine.jpg) |
| Tokyo Night | Rosé Pine |
| ![Everforest](docs/themes/everforest.jpg) | ![Catppuccin Latte](docs/themes/catppuccin-latte.jpg) |
| Everforest | Catppuccin Latte |

Latte is the one that matters: a hard-coded black scrim bruises a light theme, a
theme-coloured one keeps it bright.

---

## Where the clock goes

`layout` picks the placement. The card always keeps the date, the greeting, the
sprite, the HP bar and the field, so it stays substantial wherever the time
lands.

| | |
|---|---|
| ![card](docs/layout/card.jpg) | ![ghost](docs/layout/ghost.jpg) |
| `card` — beside the sprite | `ghost` — a theme-coloured watermark behind the card |
| ![corner](docs/layout/corner.jpg) | ![clock-above](docs/layout/clock-above.jpg) |
| `corner` — small and muted, top right | `clock-above` — on the wallpaper above the card |

A fifth, `hero`, anchors the clock high on the screen at nearly twice the size.

---

## Install

```bash
git clone https://github.com/WSeubring/omarchy-lock-pokemon ~/.config/omarchy/plugins/wseubring.lock
omarchy plugin disable omarchy.lock
omarchy restart shell
```

The plugin id is `wseubring.lock`; rename the directory *and* the `id` in
`manifest.json` together if you want your own namespace.

Sprites need `pokemon-colorscripts`:

```bash
yay -S pokemon-colorscripts-git
```

Preview it without locking yourself out:

```bash
qs -p /usr/share/omarchy/shell ipc call lock preview
qs -p /usr/share/omarchy/shell ipc call lock hidePreview
```

Plugin edits need `omarchy restart shell` to take effect — and never restart the
shell while the session is locked, or the lock client dies and Hyprland drops to
its failsafe screen.

---

## Configuration

Everything reads `[lock]` in shell.toml, which the shell assembles from the
current theme's generated file with `~/.config/omarchy/shell.toml` merged on
top. A theme owns the look; the machine-level file overrides any single key:

- theme-scoped: `~/.config/omarchy/themes/<slug>/shell.lock.toml`
  (a full-section override — it replaces the whole `[lock]` block, so repeat
  every key you want to keep)
- machine-wide: `~/.config/omarchy/shell.toml` under `[lock]`

Unset keys fall back to palette-derived defaults, so this looks right under a
theme that says nothing about the lock screen.

### Layout

| Key | Default | Meaning |
| --- | --- | --- |
| `layout` | `card` | `card`, `clock-above`, `hero`, `ghost`, `corner` |
| `card-width` | `min(720, 55%)` | px |
| `card-padding`, `card-alpha` | `30`, `0.82` | Card inset and opacity |
| `card-tint` | `0.14` | How much theme accent is mixed into the card fill |
| `tint-source` | `theme` | `theme` uses the Omarchy accent, `type` the Pokémon's |
| `card-glow` | `0.25` | Halo of the tint colour behind the card |
| `border-emphasis` | `card-quiet` | `even`, `card-quiet`, `soft-card`, `split`, `state` |
| `field-height` | `60` | Password field height (it spans the card) |
| `blur` | `1.0` | `0` leaves the wallpaper sharp |
| `scrim-color`, `scrim-alpha` | theme background, `0.5` | The wash over the wallpaper |

### Text

| Key | Default | Meaning |
| --- | --- | --- |
| `clock`, `date`, `greeting`, `status` | `show` | Section toggles |
| `clock-format`, `date-format` | `HH:mm`, `dddd d MMMM` | Qt date formats |
| `clock-size`, `date-size`, `greeting-size`, `status-size` | from the `[font]` scale | px |
| `clock-color` | type accent | `date-color`, `greeting-color`, `status-color` follow the theme |
| `user-name` | GECOS, else login name | Name in the greeting |
| `greeting-text` | time of day | Literal line; `{name}` and `{pokemon}` are substituted |
| `ghost-opacity`, `ghost-scale` | `0.2`, `3.4` | Watermark clock in `ghost` layout |

### Pokémon and effects

| Key | Default | Meaning |
| --- | --- | --- |
| `pokemon`, `pokemon-label` | `show` | Sprite, and its name/type line |
| `pokemon-name` | random | Pin one (`pikachu`) |
| `pokemon-generations` | all | `pokemon-colorscripts` range syntax, e.g. `1-3` |
| `pokemon-shiny` | `auto` | `auto` rolls the odds, `always`, or `false` |
| `shiny-odds` | `128` | One in this many locks is shiny |
| `shiny-color` | `#ffd452` | Sparkle, glow and tag colour |
| `pokemon-size`, `pokemon-height` | `12`, `170` | Glyph px, and px the sprite is scaled to |
| `pokemon-types` | `show` | Type colours on clock, glow and borders |
| `pokemon-effects` | `show` | Ambient motion and traits |
| `effect-intensity` | `1.0` | Scales shape counts (`0` = none) |
| `effect-variant` | `1` | `1` calm, `2` busy, `3` bold; per effect with `effect-variant-<name>` |
| `effect-<type>` | per type | Point a type at another effect, e.g. `effect-electric = "sparks"` |
| `dual-effects` | `show` | Layer the second type's effect behind the first |
| `dual-effect-strength` | `0.55` | Density of that second layer |

### Battery

| Key | Default | Meaning |
| --- | --- | --- |
| `battery-style` | `hp-bar` | `hp-bar`, `text` (in the status strip), or `hide` |
| `hp-colors` | `hp` | `hp` for the games' green/yellow/red, `theme` for the accent |
| `status-items` | *(empty)* | Extra strip entries: `uptime`, `keyboard` |
| `status-gap` | `22` | px |

Stock `[lock]` colour keys (`background`, `text`, `placeholder`, `text-error`,
`border`, `border-active`, `border-error`, `border-alpha`, `selection`) keep
working exactly as they do on the built-in lock screen.

### Example

```toml
[lock]
layout = "ghost"
greeting-text = "{pokemon} welcomes you back, {name}"
pokemon-generations = "1-3"
effect-electric = "sparks"
battery-style = "hide"
card-tint = 0.2
```

---

## How it is put together

| File | What it holds |
| --- | --- |
| `Service.qml` | Upstream Omarchy code: session lock, PAM, fingerprint, idle |
| `LockView.qml` | The card, its layout, and every `[lock]` token |
| `Ambient.qml` | Ten motions — rise, fall, drift, settle, streak, zigzag, expand, orbit, spiral, strike |
| `Effects.js` | Tuning for all eighteen effects, plus the calm/busy/bold multipliers |
| `Types.js` | Type → colour, effect and traits |
| `Ansi.js` | ANSI half-block art → QML rich text |
| `HpBar.qml` | The battery gauge |
| `types.json` | Every name `pokemon-colorscripts` knows → its types, from PokéAPI |

Motion is hand-rolled QtQuick animation rather than `QtQuick.Particles`: a lock
screen wants a dozen slow shapes, not a particle system, and this keeps the
plugin to plain QtQuick imports.

### Keeping up with upstream

`Service.qml` is carried verbatim. When Omarchy updates its lock plugin:

```bash
diff -u /usr/share/omarchy/shell/plugins/lock/Service.qml Service.qml
```

`types.json` is generated from PokéAPI's eighteen type endpoints, folded into
`{name: [type, ...]}`; regenerate it when a new generation lands.
