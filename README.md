# F1 Tracker — Flutter mobil

Kişisel kullanım için hazırlanmış, premium koyu temalı Android/iOS Formula 1 takip uygulaması. Bu proje resmî Formula 1/FIA uygulaması değildir.

## Bu pakette

- Jolpica ile sezon takvimi, son yarış sınıflandırması ve pilot/takım puan durumu.
- Ana sayfada sıradaki yarış, canlı geri sayım, sıradaki seans, son yarış podyumu ve şampiyona ilk 3 özeti (gerçek Jolpica verisi).
- Takvimdeki bir yarışa dokununca açılan detay ekranı: yarış sınıflandırması (grid, tur, en hızlı tur, puan), sıralama turları (Q1/Q2/Q3), sprint hafta sonlarında sprint sonuçları ve o yarıştan sonraki pilot/takım puan durumu. Yarış henüz yapılmadıysa hafta sonu programı gösterilir.
- Haberler sekmesi ve ana sayfada en yeni 3 haber: TRF1.net ve Motorsport.com Türkiye RSS akışları. Yalnızca başlık, kısa özet, kaynak adı ve tarih gösterilir; haber tarayıcıda kaynağında açılır. Kaynak filtresi, kaynak başına hata bildirimi ve çevrimdışı önbellek vardır.
- API tarih ve saatlerinin cihazın yerel saat diliminde gösterilmesi.
- Son başarılı API yanıtlarının SQLite üzerinde çevrimdışı önbelleği.
- Yükleniyor, hata/yeniden dene, önbellek ve henüz sonuç yok durumları.
- Premium koyu arayüz ve beş sekmeli mobil iskelet.
- Ücretsiz GitHub Actions Android APK ve imzasız iOS simülatör derlemesi.

## Gerçek veri ve örnek alanlar

Takvim ile Sonuçlar sekmeleri `https://api.jolpi.ca/ergast/f1/` üzerinden gerçek API verisi yükler. Ekranlar canlı API yanıtını veya çevrimdışı SQLite kopyasını kaynağıyla etiketler. Jolpica bir yarış sonucu henüz yayımlamadıysa sonuç tablosu yerine “henüz yayımlanmış sonuç yok” gösterilir. Analiz sekmesindeki içerik şimdilik örnek/boş durum tasarımıdır; FastF1 tur analizi bu pakette henüz yoktur.

Haberler şu herkese açık Türkçe RSS akışlarından gelir:

| Kaynak | Akış |
| --- | --- |
| TRF1.net | `https://trf1.net/feed/` |
| Motorsport.com Türkiye | `https://tr.motorsport.com/rss/f1/news/` |

Bu akışlar üçüncü tarafların hizmetidir; adres veya kullanım koşulları değişebilir, bir kaynak yanıt vermezse uygulama o kaynağı uyarıyla işaretler ve varsa önbellekteki haberleri gösterir. Kaynakların kendi kullanım koşullarını (özellikle uygulamayı dağıtmayı düşünürseniz) ayrıca kontrol edin.

Jolpica ücretsiz ve açık kaynaklıdır; bağımsız gönüllülerce işletilir. Erişim sınırı, kesinti veya API değişikliği olabilir. Uygulama bu durumlarda varsa yerel önbelleği kullanır. Uygulamaya ücretli API, abonelik veya zorunlu hosting eklenmemiştir.

## Bilgisayarda çalıştırma

Gereksinimler: Flutter stable (Dart 3.4+), Android/iOS platform araçları. Android ve iOS runner klasörleri başlangıç ZIP’inde bulunmayabilir. Klasörler yoksa proje kökünde bir kez üretin:

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

- `lib/core/models`: Jolpica JSON modelleri ve formatlama.
- `lib/data/remote/jolpica_repository.dart`: HTTP, toleranslı yanıt ayrıştırma, hata yönetimi ve SQLite önbellek fallback’i; tur bazlı sonuç/sıralama/sprint/puan durumu sorguları.
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
