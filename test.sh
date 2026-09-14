#!/bin/bash
# Patch a copy of Slack's app.asar and read it back with the official asar tool.
set -euo pipefail
here=$(dirname "$(realpath "$0")")
cd "$here"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Once installed, the system archive is already patched; test against the untouched backup.
src=/usr/lib/slack/resources/app.asar.orig
[[ -f $src ]] || src=/usr/lib/slack/resources/app.asar
cp "$src" "$tmp/app.asar"
ln -s /usr/lib/slack/resources/app.asar.unpacked "$tmp/app.asar.unpacked"
./slack-asar-patch "$tmp/app.asar"
[[ $(./slack-asar-patch "$tmp/app.asar") == "Slack already patched" ]]

cd "$tmp"
npx -y @electron/asar extract app.asar out >/dev/null
cp "$src" orig.asar
ln -s /usr/lib/slack/resources/app.asar.unpacked orig.asar.unpacked
npx -y @electron/asar extract orig.asar orig >/dev/null
tail -c 300 out/dist/boot.bundle.cjs | grep -q 'fs.watchFile'
node --check out/dist/boot.bundle.cjs
diff -r --exclude=boot.bundle.cjs orig out
echo "asar patch OK"

# Every installed theme, plus legacy-format themes, must generate with readable link/text colours.
python3 - "$here/omarchy-slack-theme" "$tmp" <<'EOF'
import glob, os, re, sys, types
gen = types.ModuleType("gen")
exec(open(sys.argv[1]).read(), gen.__dict__)

# Third-party themes in the wild: ANSI-only palettes (no accent, muted or shades) and short names.
LEGACY = {
    "ansi": 'background = "#1b2d40"\nforeground = "#d6e2ee"\n'
            + "".join(f'color{i} = "#{v}"\n' for i, v in enumerate(
                "1b2d40 4d86b0 5e95bc 6fa4c9 6fb8e3 8bc9eb b4e4f6 d6e2ee 4a6b80 4d86b0 5e95bc 6fa4c9 6fb8e3 8bc9eb b4e4f6 fff".split())),
    "short-names": 'accent = "#808b40"\nbg = "#0D1319"\nfg = "#F2ECCD"\nlighter_bg = "#172532"\nmuted = "#7b8a8e"\n'
                   'red = "#cf5a44"\ngreen = "#dbc66f"\nyellow = "#fff38a"\nblue = "#808b40"\nmagenta = "#e0a154"\ncyan = "#ebe36c"\n',
}
fixtures = []
for name, body in LEGACY.items():
    fixtures.append(os.path.join(sys.argv[2], f"{name}.toml"))
    open(fixtures[-1], "w").write(body)

themes = glob.glob("/usr/share/omarchy/themes/*/colors.toml") + glob.glob(os.path.expanduser("~/.config/omarchy/themes/*/colors.toml")) + fixtures
for path in themes:
    t = gen.palette(path)
    css = gen.build(t)
    bg = gen.rgb(t["background"])
    for token in ("content-hgl-1", "content-imp", "content-ter"):
        val = re.search(rf"--dt_color-{token}: (#\w+)", css).group(1)
        assert gen.contrast(gen.rgb(val), bg) >= 4.5, (path, token, val)
print(f"generator OK on {len(themes)} themes ({len(fixtures)} legacy-format)")
EOF
