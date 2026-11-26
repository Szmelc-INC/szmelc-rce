# Maintainer: Szmelc-INC <dev@szmelc.com>
#
# Arch package for Szmelc-RCE — self-hostable browser remote-control
# extension (MV3) plus its bridge backends (Node and PHP).
#
# Build & install:      makepkg -si
# Package contents:
#   /usr/share/szmelc-rce/extension/     extension (chrome://extensions →
#                                        Developer mode → Load unpacked)
#   /usr/bin/szmelc-rce-backend          Node bridge backend (backend/server.mjs,
#                                        ws vendored — no npm install needed)
#   /usr/bin/szmelc-rce-backend-php      PHP bridge backend (server.php)
#   /usr/lib/systemd/system/szmelc-rce-backend.service
#                                        unit for the Node backend; configure
#                                        via /etc/conf.d/szmelc-rce-backend
#   /usr/share/szmelc-rce/native-host/   native-messaging host (registered
#                                        system-wide for Chromium and Chrome)
#
# Native messaging is registered for the extension id
# fcoeoabgfenejglbffodgkkbkcdhcgfn (manifest `key`, unpacked installs).

pkgname=szmelc-rce
pkgver=1.1.0
pkgrel=1
pkgdesc="Self-hostable browser remote-control extension (MV3) + Node/PHP bridge backends"
arch=('any')
url="https://github.com/Szmelc-INC/szmelc-rce"
license=('MIT')
depends=('nodejs' 'php')
makedepends=('python')  # scripts/build.mjs zips via python3 -m zipfile
optdepends=('chromium: browser to load the extension into'
            'google-chrome: browser to load the extension into'
            'python-websockets: RCE_HOST_SERVE drive port in the native host')
backup=('etc/conf.d/szmelc-rce-backend'
        'etc/chromium/native-messaging-hosts/com.szmelc.rce_browser.json'
        'etc/chromium/native-messaging-hosts/com.szmelc.rce_code.json'
        'etc/opt/chrome/native-messaging-hosts/com.szmelc.rce_browser.json'
        'etc/opt/chrome/native-messaging-hosts/com.szmelc.rce_code.json')
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('0a01ad1a3da67e99718169bb1432810a4e70bce8001b1ea529f3398899b69ce0')

prepare() {
    cd "$pkgname-$pkgver"
    # Fail fast on a broken source tree (manifest refs, asset graph, secrets).
    node scripts/validate.mjs
}

build() {
    cd "$pkgname-$pkgver"
    # validate → dist/szmelc-rce/ (lean load-unpacked tree) + zip
    node scripts/build.mjs
}

package() {
    cd "$pkgname-$pkgver"

    # ---- extension (chrome://extensions → Load unpacked) --------------------
    install -dm755 "$pkgdir/usr/share/$pkgname/extension"
    cp -a dist/szmelc-rce/. "$pkgdir/usr/share/$pkgname/extension/"
    # prune non-extension material that dist/ still carries (installed elsewhere)
    rm -rf "$pkgdir/usr/share/$pkgname/extension/backend" \
           "$pkgdir/usr/share/$pkgname/extension/native-host" \
           "$pkgdir/usr/share/$pkgname/extension/pack.sh"

    # ---- backends ------------------------------------------------------------
    # Node backend + vendored ws + demo bridge; PHP backend (server.php).
    install -dm755 "$pkgdir/usr/lib/$pkgname/backend"
    cp -a backend/. "$pkgdir/usr/lib/$pkgname/backend/"
    install -Dm644 server.php "$pkgdir/usr/lib/$pkgname/server.php"
    install -Dm644 dev/bridge.mjs "$pkgdir/usr/lib/$pkgname/dev/bridge.mjs"

    install -Dm755 /dev/stdin "$pkgdir/usr/bin/szmelc-rce-backend" <<'EOS'
#!/bin/sh
# Szmelc-RCE Node bridge backend. Configuration via env:
#   PORT / HOST / RCE_API_TOKEN / RCE_PERMISSIONS / RCE_TOOL_TIMEOUT_MS
# (see backend/README.md)
exec node /usr/lib/szmelc-rce/backend/server.mjs "$@"
EOS
    install -Dm755 /dev/stdin "$pkgdir/usr/bin/szmelc-rce-backend-php" <<'EOS'
#!/bin/sh
# Szmelc-RCE PHP bridge backend: `--serve` daemon mode, or static-resolver
# mode when run under a web SAPI (php -S / FPM).
exec php /usr/lib/szmelc-rce/server.php "$@"
EOS

    # ---- systemd unit --------------------------------------------------------
    install -Dm644 /dev/stdin "$pkgdir/usr/lib/systemd/system/szmelc-rce-backend.service" <<'EOS'
[Unit]
Description=Szmelc-RCE backend (browser remote-control bridge)
Documentation=https://github.com/Szmelc-INC/szmelc-rce/blob/main/backend/README.md
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=-/etc/conf.d/szmelc-rce-backend
Environment=PORT=8080
Environment=HOST=0.0.0.0
# RCE_API_TOKEN is required on public hosts; RCE_PERMISSIONS=deny is the safe
# default (extensions' permission prompts are declined).
Environment=RCE_PERMISSIONS=deny
ExecStart=/usr/bin/szmelc-rce-backend
Restart=on-failure
DynamicUser=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOS
    install -Dm644 /dev/stdin "$pkgdir/etc/conf.d/szmelc-rce-backend" <<'EOS'
# Szmelc-RCE backend configuration (systemd EnvironmentFile)
# PORT=8080
# HOST=0.0.0.0
# RCE_API_TOKEN=change-me
# RCE_PERMISSIONS=deny
# RCE_TOOL_TIMEOUT_MS=120000
EOS

    # ---- native messaging host (system-wide) ---------------------------------
    install -Dm755 native-host/rce_host.py "$pkgdir/usr/share/$pkgname/native-host/rce_host.py"
    local host dirs=(
        /etc/chromium/native-messaging-hosts      # Chromium
        /etc/opt/chrome/native-messaging-hosts    # Google Chrome
    )
    for host in com.szmelc.rce_browser com.szmelc.rce_code; do
        for dir in "${dirs[@]}"; do
            install -Dm644 /dev/stdin "$pkgdir/$dir/$host.json" <<EOS
{
    "name": "$host",
    "description": "Szmelc-RCE native-messaging host (local bridge)",
    "path": "/usr/share/szmelc-rce/native-host/rce_host.py",
    "type": "stdio",
    "allowed_origins": [
        "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/"
    ]
}
EOS
        done
    done

    # ---- license --------------------------------------------------------------
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
