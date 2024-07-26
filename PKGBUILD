# Maintainer: Your Name <your.email@example.com>
pkgname=sand
pkgver=0.1.0
pkgrel=1
pkgdesc="A brief description of your sand program"
arch=('x86_64')
url="https://github.com/sullyj3/sand"
license=('MIT')
depends=('systemd' 'libnotify')
source=("$url/releases/download/v$pkgver/$pkgname-v$pkgver-x86_linux.tar.zst")
sha256sums=('2cfb85474a6b5debf8d279ce8336b46ed8b7452ed02b67417e1e6e566a7ab44f')

package() {
    cd "${srcdir}/release"
    
    # Install the binary
    install -Dm755 sand "${pkgdir}/usr/bin/sand"
    
    # Install documentation
    install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
    
    # Install license
    install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
    
    # Install systemd user services
    install -Dm644 resources/systemd/sand.socket "${pkgdir}/usr/lib/systemd/user/sand.socket"
    install -Dm644 resources/systemd/sand.service "${pkgdir}/usr/lib/systemd/user/sand.service"
    
    # Install additional resources
    install -Dm644 resources/timer_sound.opus "${pkgdir}/usr/share/${pkgname}/timer_sound.opus"
}
