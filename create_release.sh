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

echo "Created release in ./release"
