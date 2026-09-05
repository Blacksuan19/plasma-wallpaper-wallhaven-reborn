#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
test_root="${1:-$(mktemp -d /tmp/wallhaven-plasma-virtual.XXXXXX)}"

mkdir -p "$test_root/config" "$test_root/data" "$test_root/cache" "$test_root/runtime"
chmod 700 "$test_root/runtime"

export XDG_CONFIG_HOME="$test_root/config"
export XDG_DATA_HOME="$test_root/data"
export XDG_CACHE_HOME="$test_root/cache"
export XDG_RUNTIME_DIR="$test_root/runtime"
export WALLHAVEN_TEST_REPO_ROOT="$repo_root"
export WALLHAVEN_TEST_ROOT="$test_root"

kpackagetool6 --type Plasma/Wallpaper --install "$repo_root/package"

dbus-run-session -- kwin_wayland \
    --virtual \
    --output-count 2 \
    --width 800 \
    --height 600 \
    --no-lockscreen \
    --no-global-shortcuts \
    --no-kactivities \
    --exit-with-session "$script_dir/virtual_plasma_session.sh"
