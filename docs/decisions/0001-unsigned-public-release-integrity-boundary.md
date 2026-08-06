# ADR 0001: Sertifikasız public release bütünlük sınırı

- Durum: Kabul edildi
- Tarih: 2026-08-07

## Bağlam

Astral'ın v2.2.35 release adayı, Authenticode sertifikası bulunmadığı için güvenli biçimde yayınlanmadan durdu. Ürünün public dağıtımının sertifika edinimine bağlı kalmaması istendi. Bununla birlikte güncelleme paketinin kaynağı, içeriği ve sürümü için mevcut doğrulama kapılarının korunması gerekiyor.

## Karar

GitHub Actions release workflow'u kod imzalama secret'ları birlikte verildiğinde Authenticode imzalı, ikisi de verilmediğinde açıkça imzasız paket üretir. Secret'lardan yalnız birinin verilmesi yapılandırma hatasıdır ve release durur.

İmzalı ve imzasız yayınlarda şu kapılar zorunludur:

- Git geçmişi, çalışma ağacı ve üretilen publish dizini için Gitleaks taraması;
- tag, proje sürümü, dosya sürümü ve update manifest sürümü eşliği;
- versioned ve stable ZIP içeriği ile SHA-256 eşliği;
- GitHub release asset digest doğrulaması;
- update manifest içindeki dosya boyutu ve SHA-256 doğrulaması;
- release notunda gerçek imza durumunun belirtilmesi.

İmzalı çalışan Astral, güncelleme paketindeki PE dosyalarında aynı yayıncı imzasını aramaya devam eder. İmzasız çalışan Astral bütünlük kapılarını uygular fakat Authenticode yayıncı kimliği iddia etmez. İmzasız release notu Windows SmartScreen uyarısı görülebileceğini açıklar.

## Değerlendirilen seçenekler

- Release'i sertifika edinilene kadar engellemek: dağıtımı belirsiz süre durdurduğu için reddedildi.
- Kendinden imzalı sertifika kullanmak: kullanıcıya doğrulanmış yayıncı kimliği sağlamadığı ve güven zinciri yanılsaması yaratabildiği için reddedildi.
- Hash ve manifest denetimlerini kaldırmak: paket bütünlüğünü zayıflattığı için reddedildi.

## Sonuçlar

Sertifikasız public release mümkündür ve mevcut bütünlük zinciri korunur. Buna karşılık Windows doğrulanmış yayıncı kimliği yoktur; SmartScreen itibarı daha zayıf olabilir. İleride güvenilir bir kod imzalama sertifikası yapılandırılırsa aynı workflow yeniden imzalı paket üretir ve mevcut çalışma zamanı imza eşliği devreye girer.
