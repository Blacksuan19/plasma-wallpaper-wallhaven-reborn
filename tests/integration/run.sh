#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${1:-$(mktemp -d /tmp/wallhaven-multi-engine.XXXXXX)}"

cmake -S "$script_dir" -B "$build_dir"
cmake --build "$build_dir"
QT_QPA_PLATFORM=offscreen "$build_dir/multi_engine_sync" "$script_dir/SyncEngineClient.qml"
