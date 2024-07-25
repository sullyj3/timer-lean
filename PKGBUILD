# Maintainer: Your Name <your.email@example.com>
pkgname=sand
pkgver=108ace95506895d5f2f9b90e788b4b68544f5e56
pkgrel=1
pkgdesc="Countdown timer with CLI client and daemon"
arch=('x86_64')
url="https://github.com/sullyj3/sand"
license=('MIT')
depends=('systemd' 'libnotify')
makedepends=('git')
source=("git+https://github.com/sullyj3/sand.git")
sha256sums=('SKIP')

pkgver() {
    cd "$srcdir/$pkgname"
    # TODO better version
    git rev-parse HEAD
}

build() {
    cd "$srcdir/$pkgname"

    # TODO: I think there's currently no way to specify this
    # as a makedepend. We'll need to pre-build the executables
    # on github actions.
    lake build
}

package() {
    cd "$srcdir/$pkgname"
    
    # Install both sand and sandd to /usr/bin
    install -Dm755 .lake/build/bin/sand "$pkgdir/usr/bin/sand"
    
    # Install systemd user units
    install -Dm644 systemd/sandd.service "$pkgdir/usr/lib/systemd/user/sandd.service"
    install -Dm644 systemd/sandd.socket "$pkgdir/usr/lib/systemd/user/sandd.socket"
}
