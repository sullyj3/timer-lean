./create_release_archive.sh
pushd release/sand
sudo ./install_release.sh
popd
systemctl --user daemon-reload
systemctl --user restart sand.socket
