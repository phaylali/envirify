# AUR packaging

Two packages are published on the AUR (mirrored here for version control):

| Package | Type | Install |
|---|---|---|
| [`envirify-bin`](https://aur.archlinux.org/packages/envirify-bin) | prebuilt, points at the GitHub release asset | `paru -S envirify-bin` |
| [`envirify`](https://aur.archlinux.org/packages/envirify) | builds from the tag tarball (`makedepends=(flutter)`) | `paru -S envirify` |

They conflict with each other and both provide `envirify`.

## Releasing a new version

```sh
# 1. bump version: pubspec.yaml, both PKGBUILDs (pkgver), README numbers
# 2. tag + release
git tag -a vX.Y.Z -m "Envirify X.Y.Z" && git push origin vX.Y.Z
gh release create vX.Y.Z /tmp/envirify-X.Y.Z-linux-x86_64.tar.zst --title "Envirify X.Y.Z"

# 3. recompute hashes and update the PKGBUILDs, then push to the AUR
cd aur/envirify-bin && makepkg --printsrcinfo > .SRCINFO   # commit + push to AUR
cd aur/envirify    && makepkg --printsrcinfo > .SRCINFO   # commit + push to AUR
```
