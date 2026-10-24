#!/bin/bash
# Build the Orbit .deb from ~/orbit-src inside the Debian 13 chroot (~/trixie-build).
# Usage: build-orbit-deb.sh <version>     e.g. 0.1.0-2
set -euo pipefail
VERSION="${1:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]] || { echo "Usage: $0 <version like 0.1.0-2>"; exit 1; }
SRC=~/orbit-src; CH=~/trixie-build
PKGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P=~/pkg/orbit_${VERSION}_amd64; OUT=~/orbit_${VERSION}_amd64.deb
die() { echo "ERROR: $1" >&2; exit 1; }
[ -d "$SRC/.git" ] || die "$SRC missing"
[ -d "$CH/opt/orbit/venv" ] || die "build chroot venv missing ($CH/opt/orbit/venv)"
command -v rsync >/dev/null || die "rsync is not installed (sudo apt install -y rsync)"
[ -x "$PKGDIR/orbit" ] && [ -x "$PKGDIR/orbit-configure" ] && [ -f "$PKGDIR/control" ] || die "wrapper or control file missing in $PKGDIR"
grep -q 'cd "\$target"' "$PKGDIR/orbit" || echo "WARNING: the orbit wrapper does not cd into the project yet"
[ ! -e "$OUT" ] || die "$OUT already exists - use a new version"
if findmnt -rn -o TARGET | grep -q trixie-build; then die "unmount the chroot first"; fi
sudo -v
echo "== pulling latest Orbit =="; git -C "$SRC" pull --ff-only; git -C "$SRC" log -1 --oneline
echo "== syncing into chroot =="
sudo rsync -a --delete --exclude venv --exclude .git "$SRC/" "$CH/opt/orbit/"
sudo cp /etc/resolv.conf "$CH/etc/resolv.conf"
sudo chroot "$CH" /opt/orbit/venv/bin/pip install -q -r /opt/orbit/requirements.txt
echo "== running tests =="
T=$(sudo chroot "$CH" /bin/sh -c 'cd /opt/orbit && PATH=/opt/orbit/venv/bin:$PATH python -m unittest discover -s tests -p "test_*.py" 2>&1') \
  || { echo "$T" | tail -20; die "tests failed"; }
echo "$T" | tail -3
sudo chroot "$CH" rm -rf /opt/orbit/tests /opt/orbit/.orbit
sudo chroot "$CH" find /opt/orbit -path /opt/orbit/venv -prune -o -type d -name __pycache__ -exec rm -rf {} +
sudo chroot "$CH" /opt/orbit/venv/bin/python -m compileall -q -x '/venv/' /opt/orbit
echo "== scanning for secrets =="
if sudo grep -rIlE "sk-[A-Za-z0-9_-]{20}|AIzaSy[A-Za-z0-9_-]{30}|gsk_[A-Za-z0-9]{20}|hf_[A-Za-z0-9]{20}" "$CH/opt/orbit" --exclude-dir=venv; then
  die "possible secret in the package"
fi
echo "== building =="
sudo rm -rf "$P"; sudo mkdir -p "$P/DEBIAN" "$P/opt" "$P/usr/bin"
sudo cp -a "$CH/opt/orbit" "$P/opt/"
sudo install -m 0755 "$PKGDIR/orbit" "$P/usr/bin/orbit"
sudo install -m 0755 "$PKGDIR/orbit-configure" "$P/usr/bin/orbit-configure"
sed "s/^Version: .*/Version: $VERSION/" "$PKGDIR/control" | sudo tee "$P/DEBIAN/control" > /dev/null
sudo chmod 0644 "$P/DEBIAN/control"
sudo dpkg-deb -Zxz --root-owner-group --build "$P" "$OUT"
if dpkg-deb -c "$OUT" | grep -E '(^|/)\.env$|/config\.yaml$|/\.orbit(/|$)'; then die "unwanted files in the .deb"; fi
ls -lh "$OUT"; dpkg-deb -I "$OUT" | grep -E "Version|Depends|Maintainer"
echo; echo "Publish with:"
echo "  cd ~/galactos-repo && reprepro includedeb stable $OUT"
echo "  git add pool/ dists/ && git commit -m 'Add orbit $VERSION' && git push origin gh-pages"
