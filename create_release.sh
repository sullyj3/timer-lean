set -e

if [ ! -f .lake/build/bin/sand ]; then
    echo 'Please build the project first with `lake build`'
    exit 1
fi

mkdir -p release

cp -f .lake/build/bin/sand release/
cp -rf resources release/
cp -f scripts/install.sh release/
cp -f LICENSE release/
cp -f README.md release/

strip release/sand

tar --zstd -cvf release.tar.zst release 2>&1 > /dev/null

echo 'release created at `release`'
echo 'release archive created at `release.tar.zst`'
