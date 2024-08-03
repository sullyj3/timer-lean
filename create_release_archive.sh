set -e

if [ ! -f .lake/build/bin/sand ]; then
    echo 'Please build the project first with `lake build`'
    exit 1
fi

# git describe doesn't work by default in CI, so we use an action for it.
version=${GIT_DESCRIBE:-$(git describe)}
dir="sand-$version"

set -x

mkdir -p "release/$dir"

cp -f .lake/build/bin/sand release/$dir/
cp -f resources/systemd/sand.service release/$dir/
cp -f resources/systemd/sand.socket release/$dir/
cp -f resources/timer_sound.opus release/$dir/
cp -f scripts/install_release.sh release/$dir/
cp -f LICENSE release/$dir/
cp -f README.md release/$dir/

pushd release/ > /dev/null

strip $dir/sand

archive="$dir-x86_64-linux.tar.zst"

tar --zstd -cvf $archive $dir 2>&1 > /dev/null

popd > /dev/null

set +x

echo "release created at release/$dir"
echo "release archive created at release/$archive"
