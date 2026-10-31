#!/usr/bin/env bash
# Executed inside official openSUSE Tumbleweed container on GitHub Actions.
set -euo pipefail
version="${1:?usage: bash scripts/build.sh VERSION}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive install --no-recommends \
    rpm-build cmake ninja gcc-c++ curl ca-certificates \
    tar xz findutils coreutils git gpg2
mapfile -t deps < <(rpmspec --define "plm_version $version" -q --buildrequires packaging/plasma-login-manager-local.spec)
test "${#deps[@]}" -gt 0
zypper --non-interactive install --no-recommends "${deps[@]}"

mkdir -p .rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} out
bash scripts/verify-source.sh "$version"
cp packaging/plasma-login-manager-local.spec .rpmbuild/SPECS/
rpmbuild -bb \
    --define "_topdir ${PWD}/.rpmbuild" \
    --define "plm_version $version" \
    .rpmbuild/SPECS/plasma-login-manager-local.spec

find .rpmbuild/RPMS -type f -name '*.rpm' -exec cp -v '{}' out/ \;
test "$(find out -maxdepth 1 -name '*.rpm' | wc -l)" -eq 1
rpmfile="$(find out -maxdepth 1 -name '*.rpm' -print -quit)"
rpm -qpl "$rpmfile" > out/RPM-FILES.txt
rpm -qp --requires "$rpmfile" > out/RPM-REQUIRES.txt
rpm -qpi "$rpmfile" > out/RPM-INFO.txt
rpm -qp --scripts "$rpmfile" > out/RPM-SCRIPTS.txt
grep -q '/plasmalogin.service$' out/RPM-FILES.txt
grep -q '/pam.d/plasmalogin$' out/RPM-FILES.txt
grep -q '/sysusers.d/plasmalogin.conf$' out/RPM-FILES.txt
grep -q '/tmpfiles.d/plasmalogin.conf$' out/RPM-FILES.txt
printf '%s\n' "$version" > out/version
(cd out && sha256sum ./*.rpm > SHA256SUMS)
echo "Build complete. No display manager was enabled or installed on a host."
