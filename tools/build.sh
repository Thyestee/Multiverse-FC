#!/usr/bin/env bash
# Builds the Windows game zip and the launcher into build/.
#   tools/build.sh [version]       e.g. tools/build.sh v0.1.0
# Set GODOT to the Godot 4.7 executable if it isn't on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-dev}"
GODOT="${GODOT:-godot}"

rm -rf build
mkdir -p build/game
touch build/.gdignore  # keep the editor from scanning build output

# Stamp the version into both projects for the duration of the export, so the
# game and the launcher can show it.
cp project.godot build/project.godot.bak
cp launcher/project.godot build/launcher.godot.bak
restore() {
	cp build/project.godot.bak project.godot
	cp build/launcher.godot.bak launcher/project.godot
}
trap restore EXIT
sed -i "s|^config/version=.*|config/version=\"$VERSION\"|" project.godot launcher/project.godot

"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Windows" build/game/Multiverse-FC.exe
"$GODOT" --headless --path launcher --import
"$GODOT" --headless --path launcher --export-release "Windows" ../build/Multiverse-FC-Launcher.exe

if command -v zip >/dev/null; then
	(cd build/game && zip -q -r ../Multiverse-FC-windows.zip .)
else
	powershell -NoProfile -Command "Compress-Archive -Path 'build/game/*' -DestinationPath 'build/Multiverse-FC-windows.zip' -Force"
fi
echo "Built $VERSION:"
ls -la build/Multiverse-FC-windows.zip build/Multiverse-FC-Launcher.exe
