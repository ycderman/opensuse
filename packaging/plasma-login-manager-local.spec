Name:           plasma-login-manager-local
Version:        %{?plm_version}%{!?plm_version:6.8.2}
Release:        1%{?dist}
Summary:        KDE Plasma Login Manager from official, unmodified KDE source
License:        GPL-2.0-or-later
URL:            https://invent.kde.org/plasma/plasma-login-manager
Source0:        https://download.kde.org/stable/plasma/%{version}/plasma-login-manager-%{version}.tar.xz
ExclusiveArch:  x86_64

# Prevent competing display managers from being installed simultaneously.
Conflicts:      sddm
Conflicts:      plasma-login-manager
Conflicts:      plasma6-login-manager
Requires:       systemd
Requires:       pam

BuildRequires:  cmake
BuildRequires:  ninja
BuildRequires:  gcc-c++
BuildRequires:  gettext-tools
BuildRequires:  kf6-extra-cmake-modules
BuildRequires:  pkgconfig
BuildRequires:  pam-devel
BuildRequires:  pkgconfig(xau)
BuildRequires:  pkgconfig(systemd)
BuildRequires:  pkgconfig(libsystemd)
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6DBus)
BuildRequires:  cmake(Qt6Gui)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6Quick)
BuildRequires:  cmake(Qt6LinguistTools)
BuildRequires:  cmake(Qt6Test)
BuildRequires:  cmake(Qt6QuickTest)
BuildRequires:  cmake(Qt6ShaderTools)
BuildRequires:  cmake(KF6Config)
BuildRequires:  cmake(KF6Package)
BuildRequires:  cmake(KF6WindowSystem)
BuildRequires:  cmake(KF6I18n)
BuildRequires:  cmake(KF6DBusAddons)
BuildRequires:  cmake(KF6KCMUtils)
BuildRequires:  cmake(KF6Auth)
BuildRequires:  cmake(KF6KIO)
BuildRequires:  cmake(KF6CoreAddons)
BuildRequires:  cmake(PlasmaQuick)
BuildRequires:  cmake(LayerShellQt)
BuildRequires:  cmake(LibKWorkspace)
BuildRequires:  cmake(LibKLookAndFeel)
BuildRequires:  cmake(KF6Screen)

%description
Official, unmodified KDE Plasma Login Manager source, compiled on
openSUSE Tumbleweed. Experimental custom build: not security audited.
The package does not install or enable SDDM or automatically activate
any display manager service.

%prep
%setup -q -n plasma-login-manager-%{version}

%build
%cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DINSTALL_PAM_CONFIGURATION=ON \
    -DPAM_OS_CONFIGURATION=suse \
    -DPAM_CONFIG_DIR=%{_prefix}/lib/pam.d
cmake --build . --parallel 2

%install
DESTDIR=%{buildroot} cmake --install build
# Package the original KDE files without taking ownership of system dirs.
find %{buildroot} \( -type f -o -type l \) -printf '/%%P\n' | LC_ALL=C sort -u > files.list
test -s files.list

%post
/usr/bin/systemd-sysusers /usr/lib/sysusers.d/plasmalogin.conf >/dev/null 2>&1 || :
/usr/bin/systemd-tmpfiles --create /usr/lib/tmpfiles.d/plasmalogin.conf >/dev/null 2>&1 || :
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :

%postun
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :

%files -f files.list

%changelog
* Sat Oct 31 2026 ycderman <noreply@github.com> - 6.8.2-1
- Original KDE source RPM for openSUSE Tumbleweed; no source patches
