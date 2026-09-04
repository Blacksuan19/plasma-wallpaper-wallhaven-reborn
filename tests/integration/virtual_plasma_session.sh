#!/usr/bin/env bash

set -euo pipefail

repo_root="$WALLHAVEN_TEST_REPO_ROOT"
test_root="$WALLHAVEN_TEST_ROOT"
plasma_log="$test_root/plasmashell.log"

plasmashell >"$plasma_log" 2>&1 &
plasma_pid=$!

cleanup() {
    kill "$plasma_pid" 2>/dev/null || true
    wait "$plasma_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 100); do
    if qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

plugin_id="com.plasma.wallpaper.wallhaven"
sync_group="virtual-plasma-two-output-test"
first_image="$repo_root/screenshot.png"
second_image="$repo_root/package/contents/ui/blackscreen.jpg"
first_entry="https://w.wallhaven.cc/full/aa/wallhaven-aa1111.jpg|||https://th.wallhaven.cc/small/aa/aa1111.jpg|||$first_image|||0"
second_entry="https://w.wallhaven.cc/full/bb/wallhaven-bb2222.jpg|||https://th.wallhaven.cc/small/bb/bb2222.jpg|||$second_image|||1"

setup_script="
var screens = desktops();
print('desktop-count=' + screens.length);
for (var i = 0; i < screens.length; ++i) {
    screens[i].currentConfigGroup = ['Wallpaper', '$plugin_id', 'General'];
    screens[i].writeConfig('UseSavedWallpapers', true);
    screens[i].writeConfig('CycleSavedWallpapers', true);
    screens[i].writeConfig('ShuffleSavedWallpapers', false);
    screens[i].writeConfig('SavedWallpapers', ['$first_entry', '$second_entry']);
    screens[i].writeConfig('ShownSavedWallpapers', []);
    screens[i].writeConfig('SynchronizeScreens', true);
    screens[i].writeConfig('SyncGroupId', '$sync_group');
    screens[i].writeConfig('WallpaperDelay', 600);
    screens[i].wallpaperPlugin = '$plugin_id';
}
"

setup_output="$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$setup_script")"
printf '%s\n' "$setup_output"

expected_url="file://$first_image"
state_output=""
for _ in $(seq 1 100); do
    state_script="
var screens = desktops();
var values = [];
for (var i = 0; i < screens.length; ++i) {
    screens[i].currentConfigGroup = ['Wallpaper', '$plugin_id', 'General'];
    values.push(screens[i].readConfig('lastValidImagePath', ''));
}
print('wallpaper-state=' + values.join('|'));
"
    state_output="$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$state_script")"
    if [[ "$state_output" == *"wallpaper-state=$expected_url|$expected_url"* ]]; then
        break
    fi
    sleep 0.1
done

desktop_count="$(printf '%s\n' "$setup_output" | sed -n 's/.*desktop-count=\([0-9][0-9]*\).*/\1/p')"
database_file="$(find "$XDG_DATA_HOME/plasmashell/QML/OfflineStorage/Databases" -name '*.sqlite' -print -quit)"
database_state=""
if [[ -n "$database_file" ]]; then
    database_state="$(sqlite3 "$database_file" \
        "SELECT selection_version || '|' || json_extract(selection_json, '$.url') || '|' || coalesce(request_owner, '') FROM sync_groups WHERE group_id = '$sync_group';")"
fi

if [[ "$desktop_count" != "2" ]]; then
    printf 'FAIL: expected two Plasma desktops, got %s\n' "${desktop_count:-unknown}" >&2
    exit 1
fi
if [[ "$state_output" != *"wallpaper-state=$expected_url|$expected_url"* ]]; then
    printf 'FAIL: both wallpaper instances did not load the shared selection: %s\n' "$state_output" >&2
    exit 1
fi
if [[ "$database_state" != "1|$expected_url|" ]]; then
    printf 'FAIL: unexpected synchronization database state: %s\n' "${database_state:-missing}" >&2
    exit 1
fi

printf 'PASS: two virtual Plasma outputs loaded one shared wallpaper selection\n'
