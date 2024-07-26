#!/bin/bash

set -e

PREFIX="${PREFIX:-/usr/local}"

BIN_PATH="$PREFIX/bin/sand"
SERVICE_PATH="$PREFIX/lib/systemd/user/sand.service"
SOCKET_PATH="$PREFIX/lib/systemd/user/sand.socket"

SOUND_DIR="$PREFIX/share/sand"
SOUND_PATH="$SOUND_DIR/timer_sound.opus"

README_DIR="$PREFIX/share/doc/sand"
README_PATH="$README_DIR/README.md"

LICENSE_DIR="$PREFIX/share/licenses/sand"
LICENSE_PATH="$LICENSE_DIR/LICENSE"

install_sand() {
    set -x
    
    install -Dm755 ./.lake/build/bin/sand "$BIN_PATH"
    install -Dm644 resources/systemd/sand.service "$SERVICE_PATH"
    install -Dm644 resources/systemd/sand.socket "$SOCKET_PATH"
    install -Dm644 resources/timer_sound.opus "$SOUND_PATH"
    install -Dm644 README.md "$README_PATH"
    install -Dm644 LICENSE "$LICENSE_PATH"

    strip "$BIN_PATH"

    { set +x; } 2>/dev/null

    echo 'sand installed successfully'
    echo
    echo 'To enable and start the sand daemon, run:'
    echo '    $ systemctl --user daemon-reload'
    echo '    $ systemctl --user enable --now sand.socket'
    echo 'To check everything is working, run `sand 0`. You should get a notification and a sound.'
    echo 'To uninstall, run `sudo ./install.sh uninstall`.'
}

uninstall_sand() {
    set -x

    rm -f "$BIN_PATH" 
    rm -f "$SERVICE_PATH" 
    rm -f "$SOCKET_PATH"
    rm -rf "$SOUND_DIR" 
    rm -rf "$README_DIR" 
    rm -rf "$LICENSE_DIR"

    { set +x; } 2>/dev/null

    echo 'sand uninstalled successfully'
}

show_help() {
    echo "Usage: $0 {install|uninstall}"
    exit 1
}

case "$1" in
    install|"")
        install_sand
        ;;
    uninstall)
        uninstall_sand
        ;;
    *)
        show_help
        ;;
esac
