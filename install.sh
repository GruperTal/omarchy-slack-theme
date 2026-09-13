#!/bin/bash
# Make Slack follow the Omarchy theme. Run from a terminal (asks for sudo once).
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

install -Dm755 omarchy-slack-theme ~/.local/bin/omarchy-slack-theme

hook=~/.config/omarchy/hooks/theme-set.d/omarchy-slack-theme
cat >"$hook" <<'EOF'
#!/bin/bash
# Regenerate Slack CSS; the patched Slack picks it up live. Never fail the theme switch.
~/.local/bin/omarchy-slack-theme || logger -t omarchy-slack-theme "failed to generate Slack theme for ${1:-unknown}"
exit 0
EOF
chmod +x "$hook"

~/.local/bin/omarchy-slack-theme

sudo install -Dm755 slack-asar-patch /usr/local/bin/omarchy-slack-asar-patch
sudo tee /etc/pacman.d/hooks/omarchy-slack-theme.hook >/dev/null <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = usr/lib/slack/resources/app.asar

[Action]
Description = Re-applying Omarchy theme loader to Slack...
When = PostTransaction
Exec = /usr/local/bin/omarchy-slack-asar-patch
EOF
sudo /usr/local/bin/omarchy-slack-asar-patch
