# Changelog

Bu dosya kullanıcıya görünen sürüm geçmişini tutar. Sürüm numarası `pubspec.yaml` ve `lib/core/app_info.dart` ile eşleşir.

## [1.6.2] - 2026-11-27

### Eklendi
- Geri sayım sayacı mobil ve masaüstünde ayrı hücreler, okunabilir gün/saat/dakika/saniye etiketleri ve canlı saniye noktası.
- Masaüstü Replay oynatıcıda sol gezinme rayı korunur; pist haritası, lastik stratejisi, pit stoplar, olaylar, canlı sıralama, telemetri, hız grafiği, tur süreleri ve pilot karşılaştırması ayrı kartlarda.
- Masaüstü Ayarlar alt sayfası içerik taştığında kaydırılabilir; Hakkında kartındaki sürüm bilgisi gerçek sürümü gösterir.

## [1.6.1] - 2026-11-27

### Eklendi
- Masaüstü için kurulum paketleri: Windows `setup.exe` (NSIS), Linux `.deb` ve macOS `.dmg`.
- Kurulum paketleriyle birlikte taşınabilir zip/tar.gz paketleri de Release sayfasında kalır.

### Değiştirildi
- Güncelleme kontrolü artık v1.6.1 sürümünü bildirir.
- Masaüstü geri sayım kartındaki render/kısıt hataları giderildi.

## [1.6.0] - 2026-11-27

### Eklendi
- Windows, Linux ve macOS için tam masaüstü desteği: yan gezinme rayı, klavye kısayolları, ayarlanabilir pencere.
- Masaüstü geniş düzenleri: ana sayfada yan yana yarış/puan kartları; takvim, haberler ve sonuçlarda iki sütunlu listeler.
- Yarış detayında sıralama, sprint ve yarış sonuçları için iki sütunlu tablolar; alt sayfalarda sol menü korunur.
- Ana sayfadaki haberler doğrudan kaynak sitesinde açılır (mobil ve masaüstü).
- Ayarlar ekranında MIT lisans metni kartı ve GitHub Releases üzerinden güncelleme kontrolü butonu.
- GitHub Actions ile otomatik sürüm derlemesi ve Release sayfasına yükleme (Windows, Linux, macOS, Android).

### Değiştirildi
- Kurulumda görünen uygulama adı tüm platformlarda **F1 Tracker** olarak ayarlanır.
- Mobil görünüm korundu; yalnızca Sonuçlar tablo başlığı `POS` → `SIRA` ve Ayarlar menüsündeki lisans satırı MIT Lisansı olarak güncellendi.
- SQLite önbelleği masaüstünde işletim sisteminin uygulama destek dizininde tutulur.

### Sürüm notları
- İlk genel sürüm. İmzasız masaüstü/Android paketleri; macOS için ilk açılışta sağ tık → Open gerekebilir.
