# Sand
A systemd service and CLI program for setting countdown timers

# Installation
## Arch linux
A PKGBUILD is provided on the releases page.

1. Download the PKGBUILD into an empty directory
2. `makepkg`
3. `sudo pacman -U <built package>`

## Other distros

1. Make sure you have the dependencies: 
    - systemd
    - libnotify
    - optionally, pulseaudio or wireplumber (for timer notification sounds)

2. Download and extract the latest tarball from the releases page
3. `cd release`
4. The install script, `install.sh` is currently only tested on Arch.
   It should work on any distro that follows the FHS. However, I would
   recommend reading it and confirming that it will work correctly on your 
   distro.
5. `sudo ./install.sh`

# Setup:
After installing, you'll need to enable and start the service. 

1. `systemctl --user daemon-reload`
2. `systemctl --user enable --now sand.socket`

### Usage
```
$ sand 30

$ sand ls
#1 | 00:00:04:026 remaining

```
A notification will be triggered when the timer elapses.

### Building from source
You'll need a lean toolchain, which can be installed using [elan](https://github.com/leanprover/elan). 

Once that's done, run
```
lake build
```

The executable will be in `./.lake/build/bin/sand`.