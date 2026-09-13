# omarchy-slack-theme

Make the Slack desktop app follow your [Omarchy](https://omarchy.org) theme, and keep following it every time you switch themes. Slack recolors live, no restart needed.

Inspired by [omarchy-telegram-theme](https://github.com/gmickel/omarchy-telegram-theme), which does the same for Telegram Desktop. Siblings: [omarchy-whatsapp-theme](https://github.com/GruperTal/omarchy-whatsapp-theme), [omarchy-discord-theme](https://github.com/GruperTal/omarchy-discord-theme).

## Install

```bash
git clone https://github.com/GruperTal/omarchy-slack-theme
cd omarchy-slack-theme
./install.sh
```

Then **fully quit Slack** (closing the window only hides it to the tray; use tray → Quit or `pkill -x slack`) and start it again. That's the only restart you ever need.

For best results set Slack → Preferences → Appearance to the same mode (dark/light) as your Omarchy theme.

## How it works

Slack has no theme files, but its whole UI is painted from CSS custom properties (`--dt_color-*`, `--sk_*`).

- **`omarchy-slack-theme`** reads `~/.local/state/omarchy/current/theme/colors.toml` and writes `~/.local/state/omarchy-slack-theme/slack.css`. It overrides Slack's palette ramps (which the sidebar theme resolves through) and its semantic tokens. Text and button colours that would be unreadable are nudged until they reach 4.5:1 contrast.
- **`slack-asar-patch`** appends a small loader to Slack's main-process bundle inside `app.asar`. The loader injects that CSS into Slack and re-injects it whenever the file changes. This works because Slack's Linux build ships with Electron's asar integrity check disabled. The original is kept as `app.asar.orig`.
- **`install.sh`** installs the generator to `~/.local/bin`, adds an Omarchy `theme-set.d` hook that regenerates the CSS on every theme switch, and adds a pacman hook that re-applies the patch after Slack updates.

## Requirements

- Omarchy 4 (theme hooks + `colors.toml`)
- Slack installed at `/usr/lib/slack` (e.g. the AUR `slack-desktop` / `slack-desktop-wayland` packages)
- Python 3.11+

## Uninstall

```bash
sudo cp /usr/lib/slack/resources/app.asar.orig /usr/lib/slack/resources/app.asar
sudo rm /usr/local/bin/omarchy-slack-asar-patch /etc/pacman.d/hooks/omarchy-slack-theme.hook
rm ~/.local/bin/omarchy-slack-theme ~/.config/omarchy/hooks/theme-set.d/omarchy-slack-theme
rm -r ~/.local/state/omarchy-slack-theme
```

## Test

`./test.sh` patches a copy of your `app.asar`, reads it back with `@electron/asar`, and checks that every installed Omarchy theme generates readable colours.

## Caveats

- This modifies Slack's app files, which Slack does not support. A Slack update that changes its token names or enables asar integrity checks on Linux would break it.
- Colours Slack hard-codes outside its CSS variables stay stock.
