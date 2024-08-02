#!/bin/bash

set -e

BIN_PATH="/usr/bin/sand"
SERVICE_PATH="/usr/lib/systemd/user/sand.service"
SOCKET_PATH="/usr/lib/systemd/user/sand.socket"
SOUND_DIR="/usr/share/sand"
SOUND_PATH="$SOUND_DIR/timer_sound.opus"

install_sand() {
    set -x
    
    install -Dm755 sand             "$BIN_PATH"
    install -Dm644 sand.service     "$SERVICE_PATH"
    install -Dm644 sand.socket      "$SOCKET_PATH"
    install -Dm644 timer_sound.opus "$SOUND_PATH"

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

    rm -f "$BIN_PATH" "$SERVICE_PATH" "$SOCKET_PATH" "$SOUND_PATH"
    rm -rf "$SOUND_DIR"

    { set +x; } 2>/dev/null

    echo 'sand uninstalled successfully'
}

show_help() {
    echo "Usage: $0 {install|uninstall}"
    exit 1
}

# Check if run with sufficient permissions
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo"
    exit 1
fi

# Parse command line arguments
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
