# Changelog

Bu dosya kullanıcıya görünen sürüm geçmişini tutar. Sürüm numarası `pubspec.yaml` ve `lib/core/app_info.dart` ile eşleşir.

## [1.6.8] - 2026-11-27

### Değiştirildi
- Lastik stratejisi kartı biraz daha kısaltıldı; harita alanı biraz büyütüldü.
- Pilot karşılaştırma kartının yüksekliği artırıldı, hız grafiği kartı alçaltıldı; telemetri yüksekliği korundu.
- Masaüstü ana sayfadaki haber kartlarında başlığın yanında haber özeti de gösteriliyor.

## [1.6.7] - 2026-11-27

### Değiştirildi
- Masaüstünde üstteki boş AppBar şeridi kaldırıldı; içerik pencerenin tepesine kadar uzanıyor.
- Lastik stratejisi kartı ilk 5 pilotu gösterecek şekilde kısaltıldı.
- Harita kartına daha fazla yükseklik ayrıldı.

## [1.6.6] - 2026-11-27

### Değiştirildi
- Masaüstü ana sayfada haber kartlarının genişliği üstteki kutularla aynı hizaya getirildi.
- Masaüstü pilot karşılaştırmasındaki iki mini gösterge kaldırıldı.
- Lastik stratejisinde stintler arasına 1 px boşluk ve stint içine lastik harfi eklendi; 5 pilot sığacak yükseklikte.
- Harita kartına daha fazla yükseklik ayrıldı.
- Gap/interval süreleri virgülden sonra 3 basamakla gösteriliyor.
- Telemetri göstergesi kartın yaklaşık üçte ikisini kaplıyor; sektör alanı daraldı ve DRS simgesi eklendi.
- S1/S2/S3 daraltıldı; sektör zamanları duruma göre mor, yeşil veya sarı renkte gösteriliyor.

## [1.6.5] - 2026-11-27

### Düzeltildi
- Masaüstü Replay: iç içe `Expanded` kaynaklı yerleşim hatası ve ListTile uyarıları giderildi.
- Dar kolonda pit şeridi süresi satır taşması yapmadan gösteriliyor.
- Tur/süre bilgisi harita kartında görünüyor; masaüstü düzen testleri yeni yerleşime uyarlandı.
- Geri sayım kutularındaki rakam satırı küçük ekranlarda taşmıyor.

## [1.6.4] - 2026-11-27

### Değiştirildi
- Masaüstü Replay'de üstteki koyu kontrol şeridi kaldırıldı; kontroller harita kartına taşındı.
- Sıralama kolonu play sırasında küçülmüyor; fark süreleri pilot kodunun yanında gösteriliyor.
- Lastik stratejisi kartı fare tekeriyle kaydırılabiliyor.
- 10 sn ileri/geri için ↻ / ↺ ok simgeleri kullanılıyor.

## [1.6.3] - 2026-11-27

### Değiştirildi
- Masaüstü Replay: sıralama solda, telemetri ortada, harita sağda; kart aralıkları ve telemetri göstergesi büyütüldü.
- Replay oynatıcı açıkken sol menü yalnızca simgelere daralır; geri butonu satırı kaldırıldı.
- AppBar marka yazısı kaldırıldı; F1 TRACKER yalnızca sol menüde durur.
- Lastik stratejisi kartı tüm pilotları gösterir.

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
