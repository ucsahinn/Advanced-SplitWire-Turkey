# Astral VPN

<p align="center">
  <img src="src/Astral.App/Assets/astral-mark.png" alt="Astral uygulama ikonu" width="118">
</p>

<p align="center">
  <strong>Windows için seçili uygulama ve web hedeflerine odaklanan dar kapsamlı bağlantı yöneticisi.</strong>
</p>

<p align="center">
  <a href="https://github.com/ucsahinn/astral/releases"><img alt="GitHub release" src="https://img.shields.io/github/v/release/ucsahinn/astral?display_name=tag&style=for-the-badge"></a>
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%2B-2f81f7?style=for-the-badge&logo=windows">
  <img alt=".NET" src="https://img.shields.io/badge/.NET-8-7c3aed?style=for-the-badge&logo=dotnet">
  <img alt="Portable-ZIP" src="https://img.shields.io/badge/Portable-ZIP-22c55e?style=for-the-badge">
</p>

<p align="center">
  <a href="https://github.com/ucsahinn/astral/releases">İndir</a>
  · <a href="docs/kullanim.md">Kullanım</a>
  · <a href="docs/guncelleme.md">Güncelleme</a>
  · <a href="docs/guvenlik.md">Güvenlik</a>
  · <a href="docs/sorun-giderme.md">Sorun giderme</a>
</p>

Astral VPN, Windows'ta yalnızca kullanıcının seçtiği uygulama veya web hedefleri için bağlantı kapsamı oluşturan portable bir masaüstü uygulamasıdır. Tüm PC'yi, tüm tarayıcıyı veya sistem genelini VPN'e almayı amaçlamaz.

Uygulama hedefleri WireSock `AllowedApps` satırına dar kapsamla yazılır. Web hedeflerinde genel tarayıcı süreçleri profile eklenmez; seçili domainler `Astral.WebProxy.exe` ve PAC allowlist üzerinden yönlendirilir, diğer domainler DIRECT kalır.

Astral resmi bir Discord, Cloudflare, WireSock veya diğer marka sahibi ürünü değildir. Presetler yalnızca hedef kapsamını tanımlar; erişim durumu zamanla değişebilir.

## Ekran Görüntüleri

**Ana ekran - bağlantı kapalı**

![Astral Windows ana ekranı ve bağlantı kapalı durumu](docs/assets/screenshots/astral-windows-ana-ekran.png)

**Bağlantı açık ekranı**

![Astral Windows bağlantı açık durumu ve uygulama kapsamı](docs/assets/screenshots/astral-baglanti-aktif-ekrani.png)

## Astral Nedir?

Astral, seçili hedef/preset tabanlı bir bağlantı yöneticisidir. Kullanıcı app/web ayrımıyla uğraşmadan hedef kartlarını seçer; Astral seçimin uygulama, web veya karma kapsamını kendisi çözer.

Başlangıç presetleri:

- Discord: Uygulama + Web
- Wattpad: Web
- Bigo Live: Web
- Azar: Uygulama + Web
- Tango: Uygulama + Web
- LiVU: Uygulama + Web
- IMVU: Uygulama + Web
- Blogspot: Web
- Radio Garden: Web
- DW: Web
- VOA: Web
- Ekşi Sözlük: Web
- Grok: Web
- Imgur: Web
- Pastebin: Web

## Ne İşe Yarar?

| Özellik | Kullanıcıya etkisi |
| --- | --- |
| Tek tuşla bağlantı | Seçili hedefler için bağlantıyı açıp kapatmayı kolaylaştırır. |
| İlk ekranda hedef kartları | Discord, Wattpad, Blogspot, medya/haber/araç presetleri ve diğer hazır hedefler ana ekrandan seçilir. |
| Domain kapsamı | Web hedeflerinde yalnızca seçili domainler Astral.WebProxy üzerinden gider; diğer domainler DIRECT kalır. |
| Canlı durum kartları | DNS, bağlantı durumu ve hedef kapsamını sade biçimde gösterir. |
| Tanılama paketi | Bağlantı sorunlarını, hedef uygulama kanıtını, WebProxy runtime upstream hatalarını ve kapanış temizliği durumunu incelemek için paylaşıma uygun rapor hazırlar. |
| Portable kullanım | Kurulum sihirbazı olmadan ZIP içinden çalışır. |
| Güncelleme akışı | Yeni sürümü arka planda sessizce denetler; yalnız yeni sürüm varsa **Güncelle** düğmesini gösterir. |

## Neden Güvenli?

- Sistem DNS ayarını kalıcı değiştirmez.
- Genel tarayıcı exe'lerini WireSock `AllowedApps` kapsamına almaz.
- HTTPS içeriğini çözmez, TLS MITM yapmaz ve sertifika kurmaz; proxy yalnızca CONNECT host/Host allowlist kontrolü yapar.
- WireSock ve wgcf ikili dosyalarını repoya gömmez; release paketindeki WireSock fallback kurucusu varsa hash, imza, yayıncı ve sürümle doğrulanır.
- Arka plan videosu release paketine SHA-256 ile doğrulanmış repo-local `Assets/background.mp4` olarak eklenir; normal akışta yerel dosya oynatılır, yerel asset yüklenemezse tanılamaya yazılarak aynı doğrulanmış CloudFront kaynağı CDN fallback olarak denenir. Windows azaltılmış hareket tercihinde video ve sürekli pulse animasyonları kapatılır; manuel kapatma için `ASTRAL_DISABLE_BACKGROUND_VIDEO=1` kullanılabilir.
- Otomatik güncelleme paketini GitHub release asset bilgisi, `.sha256.txt`, GitHub digest ve manifest kontrolleriyle eşleştirir.
- Gizli profil, hesap ve log dosyalarını repoya veya release arşivine eklemez.

Daha teknik sınırlar için [güvenlik dokümanına](docs/guvenlik.md) ve [SECURITY.md](SECURITY.md) dosyasına bakın.

## Hızlı Başlangıç

1. [GitHub Releases](https://github.com/ucsahinn/astral/releases) sayfasından en güncel `Astral-win-x64.zip` arşivini indirin.
2. ZIP içeriğini istediğiniz klasöre çıkarın.
3. `Astral.exe` dosyasını çalıştırın.
4. İlk kullanım ekranında WireSock ve WARP koşullarını okuyup onaylayın.
5. Ana ekrandaki hedef kartlarından kapsamı belirleyin.
6. Ana ekranda **Bağlan** düğmesine basın.

İlk bağlantıdan önce Astral'ın yapacağı değişiklikler açıkça gösterilir:

| İşlem | Kapsam |
| --- | --- |
| Yönetici izni | WireSock sürecini, geçici firewall kapsamını ve Windows PAC/proxy durumunu yönetmek için gerekir. |
| Yardımcı araçlar | Onayınızdan sonra doğrulanmış WireSock kurucusu ve `wgcf` indirilebilir; WireSock ayrıca kurulabilir. |
| Yerel veri | Ayarlar, tanılama ve üretilen profil `%LOCALAPPDATA%\Astral` altında tutulur. |
| Geçici sistem durumu | Seçili web hedefleri için PAC/proxy ve bağlantı koruması uygulanır; bağlantı kesildiğinde geri alınır. |
| Güncelleme staging'i | Uygulama güncellemesi hazırlanırsa `%PROGRAMDATA%\Astral\updates` kullanılır. |

Release sayfasındaki ZIP paketini manuel indirdiğinizde yanındaki SHA-256 dosyasıyla doğrulayın:

```powershell
$actual = (Get-FileHash .\Astral-win-x64.zip -Algorithm SHA256).Hash
$expected = ((Get-Content -Raw .\Astral-win-x64.sha256.txt) -split '\s+')[0]
if ($actual -ne $expected) { throw 'Astral ZIP SHA-256 doğrulaması başarısız.' }
```

Değerler uyuşmazsa ZIP'i çalıştırmayın; iki dosyayı da silip resmi release sayfasından yeniden indirin. Uygulama içi otomatik güncelleme zinciri GitHub release yolu, asset digest, SHA-256 dosyası ve manifest eşleşmesi olmadan paketi uygulamaz.

## Doküman Haritası

| Konu | Bağlantı |
| --- | --- |
| Kullanım ve ilk çalıştırma | [docs/kullanim.md](docs/kullanim.md) |
| Güncelleme ve portable ZIP davranışı | [docs/guncelleme.md](docs/guncelleme.md) |
| Güvenlik sınırları | [docs/guvenlik.md](docs/guvenlik.md) |
| Sorun giderme | [docs/sorun-giderme.md](docs/sorun-giderme.md) |
| Mimari | [docs/mimari.md](docs/mimari.md) |
| Kaynak sorun denetimi | [docs/kaynak-sorun-denetimi.md](docs/kaynak-sorun-denetimi.md) |
| v2.2.36 release notu | [docs/releases/v2.2.36.md](docs/releases/v2.2.36.md) |
| v2.2.35 release notu | [docs/releases/v2.2.35.md](docs/releases/v2.2.35.md) |

## Geliştirme

Önkoşullar:

- Windows 10 veya Windows 11 x64.
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0); repo `global.json` ile `8.0.422` feature band'ini kullanır.
- Git ve Windows PowerShell 5.1+ veya PowerShell 7+.
- İlk doğrulamada NuGet restore için ağ erişimi.

Önce SDK'nın görünür olduğunu kontrol edin:

```powershell
dotnet --version
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

Başarılı doğrulama `Dogrulama basariyla tamamlandi.` satırıyla biter. Script release build'i, Core ve Windows testlerini, kaynak politikalarını, PowerShell sözdizimini ve sürüm/manifest eşliğini tek seferde denetler; varsayılan geçici build çıktısını tamamlandığında temizler. Dar bir hata üzerinde çalışırken ayrı `dotnet build` veya test projesi komutlarını kullanabilirsiniz.

Yerel contributor paketi üretmek `artifacts` altındaki aynı adlı çıktıları yeniler ve kod imzalama yapılandırılmadıysa imzasız ZIP oluşturur:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-release.ps1
```

Resmi release; temiz doğrulama, zorunlu Git-geçmişi/çalışma-ağacı/paket secret scan'leri, sürüm/tag eşliği, release notu ve paket manifest/SHA denetimi tamamlandıktan sonra GitHub Actions üzerinden üretilir. Kod imzalama sertifikası yapılandırılmışsa paket Authenticode ile imzalanır; sertifika yoksa paket imzasız yayımlanır ve bu durum release notunda açıkça belirtilir. Her iki durumda da GitHub asset digest, SHA-256 ve update manifest kapıları zorunludur. İmzalı Astral çalışma anında Updater ve WebProxy yardımcı ikililerinin aynı yayıncı imzasıyla eşleşmesini de zorunlu kılar.

## Destek ve Güvenlik

Hata bildirirken Astral sürümünü, Windows sürümünü, seçili hedefleri ve redakte edilmiş tanılama paketini ekleyin. Özel anahtar, token, cookie, `wgcf-account.toml`, tam WireGuard profili veya kişisel veri paylaşmayın.

Güvenlik açığı bildirmek için [GitHub Security Advisory](https://github.com/ucsahinn/astral/security/advisories/new) kullanın.

## Lisans ve Üçüncü Taraf Notu

Astral kaynak kodu bu repodaki [LICENSE](LICENSE) koşullarıyla yayınlanır. WireSock, Cloudflare WARP, Discord, Wattpad, Bigo Live, Azar, Tango, LiVU, IMVU, Blogspot ve diğer marka/adlar kendi sahiplerine aittir. Üçüncü taraf sınırları için [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) dosyasına bakın.
