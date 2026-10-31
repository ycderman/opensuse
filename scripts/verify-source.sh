#!/usr/bin/env bash
# Download KDE's official tarball and verify a pinned official release-manager key.
set -euo pipefail
version="${1:?usage: bash scripts/verify-source.sh VERSION}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid stable version" >&2; exit 2; }
source_dir="${PWD}/.rpmbuild/SOURCES"
out="${PWD}/out"
mkdir -p "$source_dir" "$out"
name="plasma-login-manager-${version}.tar.xz"
base="https://download.kde.org/stable/plasma/${version}"
curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
    "$base/$name" -o "$source_dir/$name"
curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
    "$base/$name.sig" -o "$source_dir/$name.sig"
curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
    "https://kde.org/info/plasma-signing-keys.pgp" -o "$out/kde-keyring.pgp"

export GNUPGHOME="${PWD}/.kde-upstream-gnupg"
mkdir -p -m 700 "$GNUPGHOME"
gpg --batch --import "$out/kde-keyring.pgp"
# Pin the Plasma release-manager primary fingerprint published on kde.org.
gpg --batch --status-fd=1 --verify \
    "$source_dir/$name.sig" "$source_dir/$name" 2>&1 | tee "$out/kde-signature.txt"
awk '$2 == "VALIDSIG" && ($3 == "0AAC775BB6437A8D9AF7A3ACFE0784117FBCE11D" || $NF == "0AAC775BB6437A8D9AF7A3ACFE0784117FBCE11D") { found = 1 } END { exit !found }' \
    "$out/kde-signature.txt"
sha256sum "$source_dir/$name" | tee "$out/kde-source.sha256"
echo "Verified official KDE source for $version against pinned release signer."
