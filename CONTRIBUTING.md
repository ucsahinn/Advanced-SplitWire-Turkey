# Katkı Rehberi

Astral'ın ürün sınırı bilinçli olarak dardır: Windows üzerinde tek düğmeyle yalnızca seçili uygulama ve web hedeflerini kapsamak.

## Geliştirme Ortamı

Gerekli araçlar:

- Windows 10/11 x64.
- `global.json` ile uyumlu .NET 8 SDK (`8.0.422` feature band'i).
- Git ve Windows PowerShell 5.1+ veya PowerShell 7+.
- İlk NuGet restore için ağ erişimi.

Repo kökünde doğrulayın:

```powershell
dotnet --version
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

SDK bulunamazsa [.NET 8 SDK'yı](https://dotnet.microsoft.com/download/dotnet/8.0) kurup yeni bir terminal açın. Başarılı doğrulamanın son satırı `Dogrulama basariyla tamamlandi.` olur. `verify.ps1` varsayılan çıktılarını geçici dizinde tutar ve tamamlandığında temizler; kalıcı execution-policy değişikliği gerekmez.

## Kabul Edilen Değişiklikler

- Seçili hedef bağlantı kararlılığı.
- WireSock ve wgcf doğrulama zinciri.
- Kurulum, tanılama ve hata mesajları.
- Türkçe kullanıcı deneyimi.
- Test, derleme ve yayın güvenliği.
- Dokümantasyon ve bildirim şablonları.

## Kabul Edilmeyen Değişiklikler

- Seçilmemiş hedeflerin, tüm tarayıcının veya tüm cihaz trafiğinin tünellenmesi.
- Genel cihaz VPN'i.
- DNS, DoH, proxy veya sistem servis ayarı ekleme.
- Üçüncü taraf ikili dosya, sürücü, kurucu veya arşiv gömme.
- TLS, imza, hash, kimlik doğrulama veya hata kontrolünü zayıflatma.
- Eski çoklu aşma motorlarını geri getirme.

## PR Kontrol Listesi

- [ ] Yalnızca seçili hedef kapsamı korunuyor.
- [ ] DNS, servis, görev zamanlayıcı veya kalıcı ağ mutasyonu eklenmedi.
- [ ] Üçüncü taraf ikili dosya veya kurucu repoya eklenmedi.
- [ ] Kullanıcıya görünen metinler Türkçe.
- [ ] `.\scripts\verify.ps1` geçti.
- [ ] Gerekliyse ekran görüntüsü veya canlı test notu eklendi.

## Hata Bildirimi

Hata bildirirken sürüm, Windows derlemesi, seçili hedefler, WireSock sürümü, internet sağlayıcısı ve redakte edilmiş tanılama bilgisini ekleyin. Gizli anahtar veya profil içeriği paylaşmayın.
