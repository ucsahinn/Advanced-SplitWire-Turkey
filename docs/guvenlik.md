# Astral Güvenlik Sınırları

Astral'ın güvenlik hedefi, seçili hedefler dışında kalan trafiği kapsam dışında bırakmaktır. Bu nedenle sistem geneli VPN, tüm tarayıcı tüneli veya kalıcı proxy aracı gibi davranmaz.

## Trafik Kapsamı

- Uygulama hedefleri WireSock `AllowedApps` satırına dar kapsamla yazılır.
- Web hedefleri için `chrome.exe`, `msedge.exe`, `firefox.exe`, `brave.exe`, `opera.exe`, `vivaldi.exe` gibi genel tarayıcı süreçleri `AllowedApps` içine eklenmez.
- Web hedeflerinde yalnız `Astral.WebProxy.exe` WireSock kapsamına girer.
- Resmi imzalı pakette WebProxy tek-file executable olarak yayımlanır; kullanım öncesinde yönetici ACL'li, reparse-point korumalı oturum staging alanına kopyalanır, imzası yeniden doğrulanır ve portable kaynak yerine bu kopyadan çalıştırılır. .NET bundle native extraction kökü de miras alınmış `%TEMP%` yerine aynı korumalı oturum alanına zorlanır.
- PAC kuralı seçili domainlerde PROXY, diğer tüm domainlerde DIRECT döndürür.
- `Astral.WebProxy` varsayılan olarak sistem DNS davranışını kullanır; Cloudflare/Google gibi public DNS fallback yalnız `ASTRAL_WEBPROXY_ALLOW_PUBLIC_DNS_FALLBACK=1` / `true` / `yes` ile açılır.
- Eski ayarlarda kalan özel hedef alanları yeni sürümde route planına taşınmaz.
- WireSock `-lac` scoped sanal ağ arayüzü modu yalnız uygulama kapsamı gereken hedeflerde açılır. Web-only seçimlerde sanal adaptör açılmaz; yalnız `Astral.WebProxy.exe` `AllowedApps` kapsamına girer ve seçili olmayan domainler PAC tarafında `DIRECT` kalır.

## TLS ve İçerik

- TLS MITM yoktur.
- Sertifika kurulmaz.
- HTTPS içeriği okunmaz veya çözülmez.
- Proxy sadece CONNECT host, HTTP Host ve domain allowlist kararını verir.

## Hedef Seçimi

- Kullanıcı yalnız hazır hedef kartlarını seçer.
- Seçim bağlantı başlamadan önce yapılır ve bağlantı açıkken kilitlenir.
- `TargetRegistry` desteklenmeyen veya eski ID'leri route planına almaz.
- Web hedefleri sadece kendi domain allowlist'iyle proxy edilir.

## İkili Dosyalar

- WireSock resmi kurucu hash, Authenticode imzası, yayıncı ve sürüm bilgisiyle doğrulanır.
- wgcf sabit SHA-256 özetiyle doğrulanır.
- Güncelleme paketi GitHub release yolu, asset digest, `.sha256.txt` ve manifest eşleşmesiyle doğrulanır.
- Arka plan videosu release paketi hazırlanırken sabit SHA-256 ile doğrulanır. Uygulama çalışma anında önce yerel `Assets/background.mp4` dosyasını oynatır; yerel asset yüklenemezse tanılamaya yazar ve aynı doğrulanmış CloudFront kaynağını CDN fallback olarak dener. Windows azaltılmış hareket tercihinde video ve hareketli durum vurguları devre dışı bırakılır; manuel kapatma için de `ASTRAL_DISABLE_BACKGROUND_VIDEO=1` kullanılabilir.

## Log ve Tanılama

Loglarda şunlar yazılmamalıdır:

- WireGuard private key.
- Token, cookie veya credential.
- Tam hassas WireGuard profili.
- Kullanıcının gereksiz kişisel verisi.

Debug tanılama isteğe bağlıdır. Normal tanılama paketi hafif tutulur ve redaksiyon uygular.
`wgcf` gibi yardımcı araçların hata çıktıları exception ve log yoluna girmeden önce kısaltılır ve anahtar/token/cookie/Authorization benzeri değerler redakte edilir.

## Rollback

PAC/proxy state'i uygulanmadan önce Astral sahiplik marker'ı ile state dosyasına alınır. Bağlantı kesilince, hata alınca, WireSock beklenmedik kapanınca veya uygulama kapanınca restore akışı çalışır. Kullanıcı veya policy bu sırada proxy ayarını değiştirmişse Astral yalnız kendi uyguladığı PAC değerini geri alır.

## Sınırlar

- Presetler erişim durumunu garanti etmez.
- PAC tarayıcı isteklerine özel bearer kimliği ekleyemediği için loopback WebProxy ayrı bir istemci token'ı doğrulamaz. Aynı makinedeki başka bir süreç aktif proxy portunu bulursa yalnız mevcut domain allowlist'i ve HTTP/80-CONNECT/443 sınırı içinde proxyyi kullanabilir veya kapasiteyi tüketmeye çalışabilir; public-IP, authority, header deadline, bağlantı sınırı ve ortak idle-timeout kontrolleri etkiyi sınırlar. Process-bound WFP/broker yetkilendirmesi ayrı bir mimari değişiklik olarak değerlendirilmelidir.
- Browser policy, DoH, QUIC, UDP/WebRTC veya manuel proxy ayarları davranışı etkileyebilir.
- Kurumsal proxy/PAC ortamlarında kullanıcı ek doğrulama yapmalıdır.
