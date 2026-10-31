# openSUSE Tumbleweed — KDE Plasma Login Manager

KDE'nin **resmî Plasma Login Manager** kaynaklarından, kaynak kodunu değiştirmeden openSUSE Tumbleweed x86_64 için RPM üretir. `cosmic-debian` projesindeki günlük otomatik derleme + GitHub Pages paket deposu yaklaşımıyla çalışır.

- Kaynak: https://invent.kde.org/plasma/plasma-login-manager
- KDE sürüm arşivleri: https://download.kde.org/stable/plasma/
- Her gün KDE'nin **kararlı** sürümlerini kontrol eder; yeni sürümü bulunca imzayı doğrular ve derler.
- GitHub Actions'ta RPM artifact'i (imzasız derleme çıktısı) oluşturulur; GPG imzalama anahtarı yapılandırılmışsa **imzalı RPM** ve imzalı `repodata` GitHub Pages'a yayımlanır.
- SDDM kurulmaz, etkinleştirilmez veya otomatik olarak değiştirilmez.
- Kaynakta değişiklik, üçüncü taraf fork/patch yoktur. Resmî KDE'nin SUSE PAM dosyaları kullanılır.
- **Tumbleweed x86_64** içindir; Leap için değildir.

> KDE, bu login manager'ı gerçek donanıma kurmanın oturum açma sorunlarına yol açabileceği konusunda uyarıyor. Derleme başarılı olsa da giriş ekranının gerçek sistemde doğrulandığı anlamına gelmez. Önce sanal makinede deneyin. GPG doğrulaması da güvenlik açığı bulunmadığını garanti etmez.

## GitHub'da tek seferlik kurulum

1. Reponun **Settings → Pages → Build and deployment → Source** ayarını **GitHub Actions** yapın.
2. Paket deposu için **ayrı ve kalıcı** bir GPG imzalama anahtarı oluşturun; özel anahtarı **Settings → Secrets and variables → Actions → New repository secret** altında **`SIGNING_KEY`** adıyla ASCII-armored biçimde ekleyin. **Özel anahtarı repoya commit etmeyin.** Anahtar parolasız olmalıdır ve yalnızca bu repo için kullanılmalıdır.
3. **Actions → Build and publish Plasma Login Manager → Run workflow** üzerinden ilk derlemeyi çalıştırın.
4. Workflow'un `publish` görevi başarılı olunca repo şu adreste yayınlanır: https://ycderman.github.io/opensuse/

Anahtar oluşturma örneği (yerel güvenilir bir Linux terminalinde):

```bash
gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-generate-key 'OpenSUSE Plasma Login RPM <plm-repo@localhost>' rsa3072 sign 0
gpg --list-secret-keys --keyid-format long
# Yalnızca BU anahtarın parmak izini seçin (FINGERPRINT).
gpg --armor --export-secret-keys FINGERPRINT > /tmp/plm-private.asc
# /tmp/plm-private.asc DOSYASININ İÇERİĞİNİ GitHub Actions SIGNING_KEY secret'ine ekleyin.
# Ardından özel anahtarın geçici disk kopyasını güvenli biçimde temizleyin.
```

Mevcut `cosmic-debian` imzalama anahtarını paylaşmak yerine ayrı anahtar önerilir. GitHub bağlantısı üzerinden repository secrets oluşturulamadığı için bu tek seferlik adımı senin yapman gerekir.

## SDDM olmadan sıfırdan kurulum

Resmî **openSUSE Tumbleweed** ISO'sunda grafik kurulum sırasında **Server** rolünü seçin (KDE/SDDM seçmeyin). Sistemi açıp TTY'ye giriş yapın:

```bash
sudo zypper refresh
sudo zypper dup
sudo zypper install --no-recommends plasma6-session konsole dolphin
rpm -q sddm
ls /usr/share/wayland-sessions/
```

`rpm -q sddm` sonucu `is not installed` olmalı. İlk Zypper işlem özeti SDDM eklemek istiyorsa onaylama. GitHub Pages deposu yayınlandıktan sonra GPG public key'i **parmak izini kontrol ederek** içeri aktarın:

```bash
curl -fsSLo /tmp/opensuse-plm.asc https://ycderman.github.io/opensuse/key.asc
gpg --show-keys --with-fingerprint /tmp/opensuse-plm.asc
sudo rpm --import /tmp/opensuse-plm.asc
sudo zypper addrepo --refresh https://ycderman.github.io/opensuse/ opensuse-plm
sudo zypper refresh opensuse-plm
sudo zypper install --no-recommends plasma-login-manager-local
sudo systemd-sysusers /usr/lib/sysusers.d/plasmalogin.conf
sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/plasmalogin.conf
sudo systemctl daemon-reload
sudo systemctl enable plasmalogin.service
sudo systemctl set-default graphical.target
sudo reboot
```

**İmza için parmak izi:** GitHub Pages deposundaki `key-fingerprint.txt` ile yerel GPG çıktısını karşılaştırın; yalnız bu karşılaştırma güven zincirini başlatmak için tek başına yeterli değildir. Anahtarı ilk kez güvenilir bir kanaldan doğrulamak gerekir. İlk açılışta `display-manager.service` alias çakışması varsa sistem servisi dosyalarını silmeyin; mevcut sağlayıcıyı kontrol edin.

Gelecekte, KDE yeni **kararlı** sürüm yayınlayınca CI doğrular, derler ve imzalayarak depoyu yeniler. Sistemde `sudo zypper dup` komutuyla güncellenir; otomatik sistem yükseltmesi yapılmaz. Zypper deposu otomatik yenilemeye açıktır.

## TTY ile kurtarma

Giriş ekranı çalışmazsa `Ctrl+Alt+F3` ile TTY'ye geçin:

```bash
sudo systemctl disable plasmalogin.service
sudo systemctl set-default multi-user.target
sudo reboot
```

Sorunu analiz etmek için: `journalctl -b -u plasmalogin.service --no-pager`.

## Dosyalar

- `.github/workflows/build.yml`: günlük kontrol, resmi imza doğrulama, RPM build, Pages publish
- `packaging/plasma-login-manager-local.spec`: upstream kaynak tabanlı RPM tanımı
- `scripts/latest.py`: KDE resmî indirme listesinden en yeni kararlı sürümü belirler
- `scripts/verify-source.sh`: KDE imzası ve sabit güvenilir imzacı parmak izi
- `scripts/build.sh`: derleme ve RPM dosya kontrolü
- `scripts/repo.sh`: RPM imzalama, `createrepo_c` ve imzalı metadata

Yayın güvenlik politikası: **geçersiz upstream imzası, eksik GPG secret, imza hatası veya RPM derleme hatasında yeni repo yayımlanmaz.** Eski çalışan repo yerinde kalır.
