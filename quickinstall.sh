./create_release.sh
pushd release/sand
sudo ./install.sh
popd
systemctl --user daemon-reload
systemctl --user restart sand.socket
