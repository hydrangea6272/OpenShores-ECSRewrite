#!/usr/bin/env bash
# Quick build entry point for Linux and WSL.
#
# Wraps the Makefile targets so you don't have to remember them:
#   ./build.sh                    scene client + servers (release, Docker)
#   ./build.sh client debug       Linux scene client, debug
#   ./build.sh servers --native   servers with the host toolchain instead of Docker
#   ./build.sh win-client         Windows client (MinGW cross-compile in Docker)
#   ./build.sh --unity            unity build: much faster full builds
#   ./build.sh --dry-run all      print the make command without running it
#
# Run ./build.sh --help for the full list.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

usage() {
    cat <<'EOF'
Usage: ./build.sh [target] [config] [options] [-DNAME=VALUE ...]

Targets:
  main        Linux scene client + multiplayer servers (default)
  client      Linux scene client
  clients     All Linux clients (scene, chat, mail, launcher)
  servers     Linux multiplayer servers (login, mail, scene)
  tools       Linux tools (hashpack, script compiler, viewer)
  linux       Every Linux program
  win-client  Windows x64 scene client (Docker cross-compile)
  win         All Windows clients (Docker cross-compile)
  all         Every Linux program and every Windows client

Configs:
  release (default), debug, relwithdebinfo

Options:
  --native    Compile Linux targets with the host's cmake/ninja/Qt5/SDL2
              instead of the Docker toolchain. Client targets still use
              Docker for audio assets. Not valid for win targets.
  --unity     Compile each library in batches of 8 files (unity build).
              About 4x faster for full builds; a one-file change rebuilds
              its whole batch. Off unless given, every run.
  --no-pch    Turn off precompiled headers (on by default).
  -DNAME=VAL  Pass a CMake cache setting through, e.g. -DAU_LINKER=default.
  --dry-run   Print the make command and exit.
  -j N        Parallel jobs for native builds (default: nproc).
  -h, --help  Show this help.

Output goes to build/<platform>-<config>/bin/.
EOF
}

target=main
config=release
native=0
dry_run=0
jobs=
unity=OFF
pch=ON
cmake_args=()
target_set=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --native) native=1 ;;
        --dry-run) dry_run=1 ;;
        --unity) unity=ON ;;
        --no-unity) unity=OFF ;;
        --no-pch) pch=OFF ;;
        --pch) pch=ON ;;
        -D?*) cmake_args+=("$1") ;;
        -j) shift; jobs=${1:?error: -j needs a number} ;;
        -j*) jobs=${1#-j} ;;
        release|debug|relwithdebinfo)
            config=$1 ;;
        -*)
            echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
        *)
            if [[ $target_set -eq 1 ]]; then
                echo "error: more than one target given: '$target' and '$1'" >&2; exit 2
            fi
            target=$1; target_set=1 ;;
    esac
    shift
done

case "$target" in
    main)       make_targets=(linux-client linux-servers) ;;
    client)     make_targets=(linux-client) ;;
    clients)    make_targets=(linux-clients) ;;
    servers)    make_targets=(linux-servers) ;;
    tools)      make_targets=(linux-tools) ;;
    linux)      make_targets=(linux) ;;
    win-client) make_targets=(win-client) ;;
    win)        make_targets=(win) ;;
    all)        make_targets=(all) ;;
    *)
        echo "error: unknown target: $target" >&2; usage >&2; exit 2 ;;
esac

is_windows_target=0
[[ "$target" == win || "$target" == win-client || "$target" == all ]] && is_windows_target=1

if [[ $native -eq 1 && $is_windows_target -eq 1 ]]; then
    echo "error: --native only applies to Linux targets; Windows clients are built in Docker." >&2
    exit 2
fi

# CMake caches options in the build directory (a Docker volume by default), so
# pass the speed settings every time rather than letting a past run's stick.
cmake_args=("-DAU_UNITY_BUILD=$unity" "-DAU_PCH=$pch" "${cmake_args[@]}")
make_args=("${make_targets[@]}" "CONFIG=$config" "CMAKE_ARGS=${cmake_args[*]}")
if [[ $native -eq 1 ]]; then
    make_args+=(NATIVE=1)
    [[ -n "$jobs" ]] && make_args+=("PARALLEL=$jobs")
fi

if [[ $dry_run -eq 1 ]]; then
    printf 'make'; printf ' %q' "${make_args[@]}"; printf '\n'
    exit 0
fi

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: '$1' not found. $2" >&2
        exit 1
    fi
}

need make "Install it with: sudo apt install make"
if [[ $native -eq 1 ]]; then
    need cmake "Install CMake 3.21+ (sudo apt install cmake)."
    need ninja "Install Ninja (sudo apt install ninja-build)."
fi

# Client targets bundle runtime audio, which mk/assets.mk always builds in
# Docker, so even native client builds need it. Native servers/tools don't.
needs_docker=1
if [[ $native -eq 1 && ( "$target" == servers || "$target" == tools ) ]]; then
    needs_docker=0
fi
if [[ $needs_docker -eq 1 ]]; then
    need docker "Install Docker (see README.md)."
    if ! docker info >/dev/null 2>&1; then
        echo "error: Docker is installed but the daemon isn't reachable." >&2
        echo "       Start Docker Desktop (with WSL integration on) or the docker service." >&2
        exit 1
    fi
fi

start=$(date +%s)
printf '==> make'; printf ' %q' "${make_args[@]}"; printf '\n'
make "${make_args[@]}"
elapsed=$(( $(date +%s) - start ))

printf '\n==> Done in %dm%02ds (%s, %s, unity %s, pch %s)\n' $((elapsed / 60)) $((elapsed % 60)) \
    "$target" "$config" "$unity" "$pch"
if [[ $native -eq 1 ]]; then
    echo "    Output: build/native-linux-$config/"
else
    [[ "$target" != win && "$target" != win-client ]] && echo "    Linux:   build/linux-$config/bin/"
    [[ $is_windows_target -eq 1 ]] && echo "    Windows: build/windows-$config/bin/"
fi
