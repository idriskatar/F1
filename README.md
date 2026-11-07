# F1 Tracker — Flutter mobil

Kişisel kullanım için hazırlanmış, premium koyu temalı Android/iOS Formula 1 takip uygulaması. Bu proje resmî Formula 1/FIA uygulaması değildir.

## Bu pakette

- Jolpica ile sezon takvimi, son yarış sınıflandırması ve pilot/takım puan durumu.
- Ana sayfada sıradaki yarış, canlı geri sayım, sıradaki seans, son yarış podyumu ve şampiyona ilk 3 özeti (gerçek Jolpica verisi).
- Takvimdeki bir yarışa dokununca açılan detay ekranı: yarış sınıflandırması (grid, tur, en hızlı tur, puan), sıralama turları (Q1/Q2/Q3), sprint hafta sonlarında sprint sonuçları ve o yarıştan sonraki pilot/takım puan durumu. Yarış henüz yapılmadıysa hafta sonu programı gösterilir.
- Haberler sekmesi ve ana sayfada en yeni 3 haber: TRF1.net ve Motorsport.com Türkiye RSS akışları. Yalnızca başlık, kısa özet, kaynak adı ve tarih gösterilir; haber tarayıcıda kaynağında açılır. Kaynak filtresi, kaynak başına hata bildirimi ve çevrimdışı önbellek vardır.
- Analiz sekmesinde OpenF1 üzerinden son tamamlanmış seansın sıralaması gösterilir. Bu hafta sonunda tamamlanmış seans yoksa önceki Grand Prix’nin son seansına geçer; ağ yoksa son başarılı sonuç önbellekten yüklenir.
- API tarih ve saatlerinin cihazın yerel saat diliminde gösterilmesi.
- Son başarılı API yanıtlarının SQLite üzerinde çevrimdışı önbelleği.
- Yükleniyor, hata/yeniden dene, önbellek ve henüz sonuç yok durumları.
- Koyu, açık ve Pitwall temaları; tercih cihazda saklanır.
- Daha fazla sekmesindeki Ayarlar ekranından değiştirilebilir RapidAPI anahtarı (Android Keystore/iOS Keychain güvenli depolaması); koyu, açık ve Pitwall temaları.
- Hakkında (geliştirici: İdris KATAR), Gizlilik politikası ve Flutter'ın açık kaynak lisans ekranı.
- Android sistem geri tuşu; açık yarış detayını kapatır, ana sekmeye döner ve Ana sayfadayken uygulamadan çıkar.
- Yedi simgeli mobil gezinme: Ana sayfa, Takvim, Canlı, Haberler, Sonuçlar, Analiz ve Daha fazla. Dikey ekranda alt çubukta metin etiketleri gösterilmez; Ayarlar ve bilgilendirme sayfaları Daha fazla bölümündedir.
- Ücretsiz GitHub Actions Android APK ve imzasız iOS simülatör derlemesi.

## Gerçek veri ve örnek alanlar

Takvim ile Sonuçlar sekmeleri `https://api.jolpi.ca/ergast/f1/` üzerinden gerçek API verisi yükler. Ekranlar canlı API yanıtını veya çevrimdışı SQLite kopyasını kaynağıyla etiketler. Jolpica bir yarış sonucu henüz yayımlamadıysa sonuç tablosu yerine “henüz yayımlanmış sonuç yok” gösterilir. Analiz sekmesi OpenF1’den tarihsel seans sıralaması getirir; tur temposu, lastik, sektör ve pit-stop grafikleri daha sonra aynı seans verisine bağlanacaktır.

Haberler şu herkese açık Türkçe RSS akışlarından gelir:

| Kaynak | Akış |
| --- | --- |
| TRF1.net | `https://trf1.net/feed/` |
| Motorsport.com Türkiye | `https://tr.motorsport.com/rss/f1/news/` |

Bu akışlar üçüncü tarafların hizmetidir; adres veya kullanım koşulları değişebilir, bir kaynak yanıt vermezse uygulama o kaynağı uyarıyla işaretler ve varsa önbellekteki haberleri gösterir. Kaynakların kendi kullanım koşullarını (özellikle uygulamayı dağıtmayı düşünürseniz) ayrıca kontrol edin.

Jolpica ücretsiz ve açık kaynaklıdır; bağımsız gönüllülerce işletilir. Erişim sınırı, kesinti veya API değişikliği olabilir. Uygulama bu durumlarda varsa yerel önbelleği kullanır. Uygulamaya ücretli API, abonelik veya zorunlu hosting eklenmemiştir.

OpenF1, 2023 sezonundan itibaren tarihsel seans verisini kimlik doğrulama olmadan sunar. Analiz sekmesi yalnızca bitişi en az 30 dakika geçmiş seansları sorgulayarak tarihsel uçları kullanır; canlı veri aboneliği gerektirmez. Seans sonuçları OpenF1 tarafından resmi sonuç yayımlandıktan birkaç dakika sonra eklenir. Kaynak/API koşulları değişebilir.

Canlı sekmesi F1 Live Pulse RapidAPI uç noktasını çağırır. Anahtarı **Daha fazla → Ayarlar → Canlı veri API anahtarı** bölümünden ekleyebilir, istediğiniz zaman yenisiyle değiştirebilir veya silebilirsiniz. Anahtar uygulamanın koduna ya da GitHub deposuna yazılmaz; cihazın güvenli depolamasında tutulur. Live Pulse verisi için RapidAPI tarafında ücretsiz plan etkin olmalıdır; ücretsiz kota sağlayıcı limitlerine bağlıdır. Takvim, Jolpica sonuçları ve OpenF1 analizleri anahtar istemez. Live Pulse yanıt şeması sağlayıcı tarafından değiştirilebilir; uygulama desteklenen yaygın liste/sözlük biçimlerini ayrıştırır ve tanınmayan yanıtın üst seviye alan adlarını hata mesajında gösterir.

**Analiz 401 uyarısı:** Analiz OpenF1 kullanır ve RapidAPI anahtarı OpenF1 kimlik doğrulaması yerine geçmez. OpenF1 dokümanına göre 2023 ve sonrası tarihsel veriler ücretsiz/anahtarsız erişilebilir; servis 401/403 döndürürse uygulama daha eski sezonları da dener ve erişim hâlâ reddedilirse bunu ayrı bir hata olarak bildirir. [OpenF1 dokümanı](https://openf1.org/docs/) ve [kimlik doğrulama rehberi](https://openf1.org/auth.html).

## Bilgisayarda çalıştırma

Gereksinimler: Flutter stable (Dart 3.4+), Android/iOS platform araçları. Güvenli RapidAPI anahtarı deposu Android 6.0 / API 23 veya üzerini gerektirir. Android ve iOS runner klasörleri başlangıç ZIP’inde bulunmayabilir. Klasörler yoksa proje kökünde bir kez üretin:

```bash
flutter create --platforms=android,ios .
python3 tool/configure_app_name.py
flutter pub get
flutter analyze
flutter test
flutter run
```

iOS derlemesi için macOS ve Xcode gerekir. Yerel Android sürüm derlemesi: `flutter build apk --release`.
Kurulumda görünen uygulama adı **F1 Tracker** olarak yapılandırılır. GitHub Actions bu ayarı derleme sırasında uygular; yerel Android/iOS runner klasörlerini yeni oluşturduğunuzda yukarıdaki yapılandırma betiğini çalıştırın. Dart paket adı ve import yolu `f1_tracker` olarak kalır.

## GitHub’a yükleme ve commit

1. Bu paketteki `f1-tracker-jolpica-mobile.zip` dosyasını bilgisayarda yeni bir klasöre çıkarın. GitHub deponuzun `main` dalında başlangıç projesi zaten varsa, çıkarılmış dosyaları deponun köküne kopyalayın ve mevcut dosyaların üzerine yazın. `android/` ve `ios/` klasörleri yerelde oluşturulmuşsa bunları da ekleyin; yoksa Actions kendisi üretir.
2. GitHub’da deponuzu açın. **Add file → Upload files** seçip proje kökündeki dosya ve klasörleri yükleme alanına bırakın. Gizli `.github` klasörünün içindeki `.github/workflows/build-mobile.yml` dosyasının da eklendiğini kontrol edin. Web arayüzü gizli klasörü yüklemiyorsa **Add file → Create new file** seçin, dosya yolu alanına `.github/workflows/build-mobile.yml` yazın ve bu dosyanın içeriğini projedeki aynı adlı workflow’dan kopyalayın.
3. **Commit changes** bölümünde örneğin `Add Jolpica mobile integration` mesajını yazın ve `Commit directly to the main branch` seçiliyken **Commit changes** düğmesine basın. Deponuzun varsayılan dalı `main` değilse GitHub Actions dosyasındaki `branches: [main]` değerini kendi dal adınızla değiştirin.

Git kuruluysa alternatif olarak proje klasöründe:

```bash
git init
git add .
git commit -m "Add Jolpica mobile integration"
git branch -M main
git remote add origin https://github.com/USERNAME/REPOSITORY.git
git push -u origin main
```

`USERNAME/REPOSITORY` yerine kendi depo adresinizi yazın. Mevcut yerel Git deposunda `git init` ve `git remote add` adımlarını tekrarlamayın; dosyaları kopyalayıp `git add .`, `git commit -m "Add Jolpica mobile integration"` ve `git push` kullanın.

## GitHub Actions ile derleme ve indirme

1. Deponun **Actions** sekmesini açın ve **F1 Tracker Mobile Build** iş akışını seçin.
2. Elle başlatmak için **Run workflow → Run workflow** seçin. `main` dalına bu workflow veya uygulama dosyalarından birini içeren commit gönderildiğinde de otomatik çalışır.
3. Çalışma tamamlandığında iş akışı özetindeki **Artifacts** bölümünden `f1-tracker-android` ve/veya `f1-tracker-ios-simulator` dosyasını indirin.
4. Android arşivini açın; içindeki `app-release.apk` Android cihaza kurulabilir. iOS arşivi yalnızca simülatör için derlenmiş, imzasız `Runner.app` içerir; TestFlight veya fiziksel iPhone kurulumu için Apple imzalama/provisioning gerekir ve bu workflow bunları yapmaz.

Actions adımları Android’de `flutter analyze` ve `flutter test` çalıştırır, ardından release APK üretir. iOS işi imzasız simülatör uygulaması oluşturur; App Store paketi değildir. GitHub’ın Actions dakikaları ve artifact saklama politikaları hesabın planına/limitlerine bağlı olabilir.

## Teknik yapı

- `lib/core/models`: Jolpica ve OpenF1 JSON modelleri ve formatlama.
- `lib/data/remote/jolpica_repository.dart`: HTTP, toleranslı yanıt ayrıştırma, hata yönetimi ve SQLite önbellek fallback’i; tur bazlı sonuç/sıralama/sprint/puan durumu sorguları.
- `lib/data/remote/openf1_repository.dart`: Son tarihsel seansı, sonuçlarını ve pilot bilgilerini yükler; SQLite çevrimdışı fallback’i sağlar.
- `lib/data/remote/f1_live_pulse_client.dart` ve `lib/data/local/rapid_api_key_store.dart`: RapidAPI canlı zamanlama istemcisi ve cihaz güvenliğinde API anahtarı saklama.
- `lib/features/settings/settings_screen.dart`, `lib/features/more/more_screen.dart` ve `lib/core/theme/app_theme.dart`: güvenli API anahtarı/tema tercihleri, hakkında/gizlilik/lisans sayfaları ve renk paletleri.
- `lib/features/shell/app_shell.dart`: sekme gezinmesi ve Android sistem geri tuşunun sekme/detay davranışı.
- `lib/core/models/news_models.dart` ve `lib/data/remote/news_repository.dart`: RSS/Atom ayrıştırma, kaynakları birleştirme/sıralama, kaynak bazlı hata ve önbellek.
- `lib/features/calendar/race_detail_screen.dart`: yarış detay ekranı.
- `test/`: sahte HTTP istemcisi ve sabit saatle model, repository ve ekran testleri (`test/support/fakes.dart`).
- `lib/data/local/local_store.dart`: platform yerel SQLite cache.
- `lib/features`: premium temalı mobil ekranlar.
- `.github/workflows/build-mobile.yml`: Android ve iOS simülatör CI işleri.

## Sonraki işler

- FastF1 ile yarış sonrası tur/sektör/lastik analizini içe aktarmak.
- Platform cihaz derlemelerini ve entegrasyon testlerini genişletmek (widget/model testleri büyük ölçüde eklendi).

F1, Formula 1 ve takım/pilot adları ilgili sahiplerinin markalarıdır. Bu bağımsız kişisel proje Formula 1, FIA veya herhangi bir takımla bağlantılı değildir.
