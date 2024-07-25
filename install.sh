
install -Dm755 .lake/build/bin/sand /usr/bin/sand
install -Dm644 resources/systemd/sand.service /usr/lib/systemd/user/sand.service
install -Dm644 resources/systemd/sand.socket /usr/lib/systemd/user/sand.socket
install -Dm644 resources/timer_sound.opus /usr/share/sand/timer_sound.opus

systemctl --user daemon-reload