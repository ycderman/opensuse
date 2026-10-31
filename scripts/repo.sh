#!/usr/bin/env bash
# Sign RPMs + rpm-md metadata using the persistent GitHub Actions SIGNING_KEY.
set -euo pipefail
input="${1:?usage: bash scripts/repo.sh BUILD_OUT SITE_DIR}"
site="${2:?usage: bash scripts/repo.sh BUILD_OUT SITE_DIR}"
: "${SIGNING_KEY:?Configure the SIGNING_KEY Actions secret before publishing}"
test -s "$input/version"
mapfile -t rpms < <(find "$input" -maxdepth 1 -type f -name '*.rpm' -print)
test "${#rpms[@]}" -eq 1 || { echo "Expected exactly one built RPM" >&2; exit 1; }
(cd "$input" && sha256sum -c SHA256SUMS)

export GNUPGHOME
GNUPGHOME="$(mktemp -d)"
chmod 700 "$GNUPGHOME"
trap 'gpgconf --kill gpg-agent >/dev/null 2>&1 || :; rm -rf "$GNUPGHOME"' EXIT
printf '%s\n' "$SIGNING_KEY" | gpg --batch --import
mapfile -t fingerprints < <(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" {print $10}')
test "${#fingerprints[@]}" -eq 1 || { echo "SIGNING_KEY must contain exactly one signing identity" >&2; exit 1; }
fingerprint="${fingerprints[0]}"
test -n "$fingerprint"

mkdir -p "$site/x86_64"
gpg --armor --export "$fingerprint" > "$site/key.asc"
printf '%s\n' "$fingerprint" > "$site/key-fingerprint.txt"
cp "${rpms[0]}" "$site/x86_64/"
rpmfile="$site/x86_64/$(basename "${rpms[0]}")"
# RPM 4.x/6.x-compatible GnuPG signing configuration.
rpmsign \
    --define "_gpg_name $fingerprint" \
    --define "_openpgp_sign_id $fingerprint" \
    --define "_gpg_path $GNUPGHOME" \
    --define "_openpgp_sign gpg" \
    --addsign "$rpmfile"

# Fail closed unless this locally produced RPM has a verifiable signature.
rpm --import "$site/key.asc"
rpm --checksig "$rpmfile" | tee "$site/RPM-SIGNATURE.txt" | grep -q ': .*OK$'
createrepo_c --quiet "$site/x86_64"
gpg --batch --yes --armor --detach-sign --local-user "$fingerprint" \
  -o "$site/x86_64/repodata/repomd.xml.asc" \
  "$site/x86_64/repodata/repomd.xml"
gpg --batch --verify "$site/x86_64/repodata/repomd.xml.asc" \
  "$site/x86_64/repodata/repomd.xml"

cat > "$site/opensuse-plm.repo" <<'EOF'
[opensuse-plm]
name=KDE Plasma Login Manager (official KDE source, custom openSUSE build)
enabled=1
autorefresh=1
baseurl=https://ycderman.github.io/opensuse/x86_64/
type=rpm-md
gpgcheck=1
repo_gpgcheck=1
pkg_gpgcheck=1
gpgkey=https://ycderman.github.io/opensuse/key.asc
EOF

cp "$input/version" "$site/version"
cp "$input/kde-source.sha256" "$site/"
cp "$input/kde-signature.txt" "$site/"
cp "$input/RPM-INFO.txt" "$site/"
cp "$input/RPM-FILES.txt" "$site/"
(cd "$site/x86_64" && sha256sum ./*.rpm > SHA256SUMS)
cat > "$site/index.html" <<'EOF'
<!DOCTYPE html><html lang="en"><meta charset="utf-8">
<title>KDE Plasma Login Manager openSUSE RPM</title>
<h1>KDE Plasma Login Manager — openSUSE Tumbleweed x86_64</h1>
<p>Unofficial package, built from verified official KDE release sources.</p>
<p>For install instructions see
<a href="https://github.com/ycderman/opensuse">github.com/ycderman/opensuse</a>.</p>
<p><a href="opensuse-plm.repo">Zypper repository configuration</a></p>
<p><a href="key.asc">Repository signing public key</a></p>
<p><a href="key-fingerprint.txt">Signing key fingerprint</a></p>
<p><a href="x86_64/">RPM and signed repodata</a></p>
</html>
EOF
echo "Signed RPM and signed repository for version $(cat "$site/version")"
