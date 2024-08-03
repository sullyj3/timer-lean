# Sand

Command line countdown timers that don't take up a terminal.

`sand` runs as a daemon in the background, allowing you to set timers
without having to worry about keeping the terminal open. You can also start 
timers from your app launcher/command runner of choice.

```bash
$ sand 5m
Timer created for 00:05:00:000.
$ sand 1h 30s
Timer created for 01:00:30:000.
$ sand ls
#2 | 01:00:27:313 remaining
#1 | 00:04:51:340 remaining
```
A sound will play and a desktop notification will be triggered when a timer 
elapses.

I use it for remembering to get things out of the oven.

## Installation

1. Make sure you have the dependencies: 
    - systemd
    - libnotify
    - optionally, pulseaudio or wireplumber (for timer notification sounds)

2. Download and extract the latest tarball from the releases page
3. The install script, `install_release.sh` is currently only tested on Arch.
   It should work on any distro that follows the FHS. However, I would
   recommend reading it and confirming that it will work correctly on your 
   distro.
4. inside the release directory, run `sudo ./install_release.sh`

## Setup
After installing, you'll need to enable and start the service. 

```bash
$ systemctl --user daemon-reload
$ systemctl --user enable --now sand.socket
```

To see notifications, you'll need a libnotify compatible notification server. I use [swaync](https://github.com/ErikReider/SwayNotificationCenter).

You can type 
```bash
$ sand 0
```
to check everything's working correctly.

## Building from source
You'll need a lean toolchain, which can be installed using [elan](https://github.com/leanprover/elan). 

Once that's done, run
```bash
$ lake build
```

The executable will be in `./.lake/build/bin/sand`.
