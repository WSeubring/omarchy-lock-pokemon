# Pokémon Lock Screen (Omarchy shell plugin)

A cloned `omarchy.lock` for [Omarchy](https://omarchy.org/) 4's Quickshell shell.
Same PAM flows as the stock lock screen (password + fingerprint, untouched), with
the view rebuilt: a Pokémon sprite greeting, a big clock, a personal greeting and
a status strip, all driven by theme tokens.

![lock screen](docs/lock.png)

## What it adds

- **Pokémon sprite** rendered from [`pokemon-colorscripts`](https://gitlab.com/phoneybadger/pokemon-colorscripts)
  ANSI art, converted to rich text (`Ansi.js`). A fresh random one per lock, or
  pin one by name. Missing binary = no sprite, no error.
- **Clock, date and greeting** — the greeting follows the time of day, or takes a
  literal line with `{name}` / `{pokemon}` placeholders.
- **Status strip**: battery, uptime, keyboard layout. Each entry disappears when
  its source has nothing to say.
- **Wrong-password shake** on the input field.
- **Vertical scrim** over the blurred wallpaper so light backgrounds stay readable.

Everything is optional and every value is a token — see below.

## Install

```bash
git clone https://github.com/WSeubring/omarchy-lock-pokemon ~/.config/omarchy/plugins/wseubring.lock
omarchy plugin disable omarchy.lock
omarchy restart shell
```

The plugin id is `wseubring.lock`; rename the directory *and* `id` in
`manifest.json` together if you want your own namespace.

Optional but recommended:

```bash
yay -S pokemon-colorscripts-git
```

Preview it without locking:

```bash
qs -p /usr/share/omarchy/shell ipc call lock preview
qs -p /usr/share/omarchy/shell ipc call lock hidePreview
```

## Theming

Every knob reads `[lock]` in shell.toml, which the shell assembles from the
current theme's generated file with `~/.config/omarchy/shell.toml` merged on
top. So a theme owns the look, and the machine-level file overrides any single
key without touching the theme:

- theme-scoped: `~/.config/omarchy/themes/<slug>/shell.lock.toml`
  (a full-section override — repeat every key of `[lock]`, it replaces the block)
- machine-wide: `~/.config/omarchy/shell.toml` under `[lock]`

Unset keys fall back to palette-derived defaults, so the plugin still looks
right under a theme that says nothing about the lock screen.

| Key | Default | Meaning |
| --- | --- | --- |
| `clock`, `date`, `greeting`, `status`, `pokemon`, `pokemon-label` | `show` | Section toggles (`show`/`hide`) |
| `clock-format`, `date-format` | `HH:mm`, `dddd d MMMM` | Qt date formats |
| `clock-size`, `date-size`, `greeting-size`, `status-size` | from the `[font]` scale | px |
| `clock-color`, `date-color`, `greeting-color`, `status-color` | `text` / `placeholder` | hex, role name, or a `section.key` reference; a gradient reference uses its first stop |
| `user-name` | GECOS, else login name | Name used in the greeting |
| `greeting-text` | time-of-day greeting | Literal line; `{name}` and `{pokemon}` are substituted |
| `status-items` | `battery uptime keyboard` | Which entries the strip shows |
| `status-gap`, `status-margin` | `26`, `48` | px |
| `pokemon-name` | random | Pin a Pokémon (`pikachu`) |
| `pokemon-generations` | all | `pokemon-colorscripts` range syntax, e.g. `1-3` |
| `pokemon-shiny` | `false` | Shiny sprites |
| `pokemon-size` | `11` | px; the sprite is scaled down further to fit above the clock |
| `field-width`, `field-height` | `381`, `67` | Password field size |
| `blur` | `1.0` | `0` leaves the wallpaper sharp |
| `scrim-alpha` | `0.55` | `0` removes the darkening wash |

Stock `[lock]` color keys (`background`, `text`, `placeholder`, `text-error`,
`border`, `border-active`, `border-error`, `border-alpha`, `selection`) keep
working as they do on the built-in lock screen. Pointing `border` at
`hyprland.active-border` gives the field the theme's window-border gradient.

### Example

```toml
[lock]
greeting-text = "{pokemon} welcomes you back, {name}"
pokemon-generations = "1-3"
status-items = "battery keyboard"
scrim-alpha = 0.35
```

## Keeping up with upstream

This is a clone of Omarchy's `omarchy.lock`, so `Service.qml` (session lock,
PAM, fingerprint, idle handling) is upstream code carried verbatim. When Omarchy
updates its lock plugin, diff and reapply:

```bash
diff -u /usr/share/omarchy/shell/plugins/lock/Service.qml Service.qml
```

`LockView.qml` and `Ansi.js` are the parts that are actually mine.
