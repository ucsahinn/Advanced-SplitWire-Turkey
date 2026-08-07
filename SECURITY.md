# Güvenlik Politikası

Astral dar kapsamlı bir Windows aracıdır: yalnızca kullanıcının seçtiği uygulama ve web hedefleri için bağlantı kapsamı oluşturur; tüm PC'yi, tüm tarayıcıyı veya sistem genelini VPN'e almayı amaçlamaz.

## Desteklenen Sürüm

Yalnızca `main` dalı ve en son yayınlanan sürüm güvenlik düzeltmesi alır.

## Güvenlik Açığı Bildirimi

Güvenlik açıklarını herkese açık bildirim olarak paylaşmayın. Şu durumlarda GitHub özel güvenlik bildirimi kullanın:

<https://github.com/ucsahinn/astral/security/advisories/new>

Özellikle şunları gizli bildirin:

- İmza, hash veya yayıncı doğrulamasını atlatan açıklar.
- WireSock veya wgcf indirme zincirinde bütünlük zayıflığı.
- Seçili olmayan uygulama veya domainlerin tünele alınmasına yol açan hatalar.
- Gizli profil, hesap veya anahtar sızıntısı.
- TLS doğrulamasını zayıflatan regresyonlar.

## Gizli Veri Paylaşmayın

Bildirimlere şunları eklemeyin:

- WireGuard özel anahtarı.
- `wgcf-account.toml`.
- Token, cookie, bağlantı dizesi veya kişisel veri.
- Tam profil dosyası.
- Redakte edilmemiş log.

## Güvenlik Sınırları

- WireSock VPN Client `1.4.7.1` yalnızca resmi indirme noktasından alınır.
- Kurucu sabit SHA-256 değeriyle doğrulanır.
- Authenticode imzası, yayıncı, MSI ürün adı ve sürüm bilgisi kontrol edilir.
- WireSock ve Cloudflare WARP koşulları kullanıcı onayı olmadan kabul edilmiş sayılmaz.
- Repoda WireSock veya wgcf ikili dosyası tutulmaz. Yayın arşivi doğrulanmış bir WireSock fallback kurucusu içerebilir; `wgcf` çalışma zamanında resmi sabit URL ve SHA-256 ile indirilir.
- Hassas `wgcf-account.toml` ve üretilen WireGuard profil dosyaları `%PROGRAMDATA%\Astral` altında, yönetici erişimli uygulama veri alanında kalır.
- `%LOCALAPPDATA%\Astral` yalnız kullanıcı ayarları, loglar ve PAC durum verisi için kullanılır.

### İmzasız Dağıtım Sınırı

İmzasız Astral paketinde ZIP/SHA-256/manifest denetimleri bütünlük tutarlılığı sağlar; Authenticode yayıncı kimliği veya GitHub hesabından bağımsız bir güncelleme güven kökü sağlamaz. Portable klasör kullanıcı tarafından yazılabiliyorsa yönetici olarak çalışan Astral'ın yanındaki `Astral.Updater.exe` veya `Astral.WebProxy.exe` başka bir yerel süreç tarafından değiştirilebilir. Paketi doğruladıktan sonra yalnız güvendiğiniz, başka kullanıcı ve süreçlerin yazamadığı bir klasöre çıkarın; çalıştırmadan önce klasör içeriğini değiştirmeyin. Daha yüksek güvence gereken dağıtımlarda Authenticode imzalı paket kullanılmalıdır.

## Yerel Veri Temizliği

Hassas hesap ve profil verisini elle klasör silerek kaldırmayın. Önce Astral içindeki **Profili Temizle** eylemini kullanın; bu akış bağlantı kapsamını güvenli biçimde kapatır ve uygulamanın yönettiği `%PROGRAMDATA%\Astral` profil verisini kontrollü olarak temizler. `%LOCALAPPDATA%\Astral` ayar, log ve PAC durum verisini içerir; yalnız bu kullanıcı verisini sıfırlamak istediğinizde, Astral tamamen kapalıyken ayrıca temizlenebilir. WireSock ayrı bir Windows uygulamasıdır; kaldırmak için Windows Ayarları üzerinden işlem yapın.
