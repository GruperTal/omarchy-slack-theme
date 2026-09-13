#!/bin/bash
# Patch a copy of Slack's app.asar and read it back with the official asar tool.
set -euo pipefail
here=$(dirname "$(realpath "$0")")
cd "$here"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp /usr/lib/slack/resources/app.asar "$tmp/app.asar"
ln -s /usr/lib/slack/resources/app.asar.unpacked "$tmp/app.asar.unpacked"
./slack-asar-patch "$tmp/app.asar"
[[ $(./slack-asar-patch "$tmp/app.asar") == "Slack already patched" ]]

cd "$tmp"
npx -y @electron/asar extract app.asar out >/dev/null
npx -y @electron/asar extract /usr/lib/slack/resources/app.asar orig >/dev/null
tail -c 300 out/dist/boot.bundle.cjs | grep -q 'fs.watchFile'
node --check out/dist/boot.bundle.cjs
diff -r --exclude=boot.bundle.cjs orig out
echo "asar patch OK"

# Every installed theme must generate, with readable link/text colours.
python3 - "$here/omarchy-slack-theme" <<'EOF'
import glob, os, re, sys, tomllib, types
gen = types.ModuleType("gen")
exec(open(sys.argv[1]).read(), gen.__dict__)
themes = glob.glob("/usr/share/omarchy/themes/*/colors.toml") + glob.glob(os.path.expanduser("~/.config/omarchy/themes/*/colors.toml"))
for path in themes:
    t = tomllib.load(open(path, "rb"))
    css = gen.build(t)
    bg = gen.rgb(t["background"])
    for token in ("content-hgl-1", "content-imp", "content-ter"):
        val = re.search(rf"--dt_color-{token}: (#\w+)", css).group(1)
        assert gen.contrast(gen.rgb(val), bg) >= 4.5, (path, token, val)
print(f"generator OK on {len(themes)} themes")
EOF
