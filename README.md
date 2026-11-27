# F1 Tracker — Flutter (mobil + masaüstü)

Kişisel kullanım için hazırlanmış, premium koyu temalı Android/iOS ve Windows/Linux/macOS Formula 1 takip uygulaması. Bu proje resmî Formula 1/FIA uygulaması değildir.

## İndir

**En son sürüm: [v1.6.3](https://github.com/idriskatar/F1/releases/latest)**

| Platform | Kurulum | Taşınabilir |
| --- | --- | --- |
| Windows | [F1-Tracker-Setup-v1.6.3.exe](https://github.com/idriskatar/F1/releases/download/v1.6.3/F1-Tracker-Setup-v1.6.3.exe) | [zip](https://github.com/idriskatar/F1/releases/download/v1.6.3/F1-Tracker-Windows-v1.6.3.zip) |
| Linux | [f1-tracker_1.6.3_amd64.deb](https://github.com/idriskatar/F1/releases/download/v1.6.3/f1-tracker_1.6.3_amd64.deb) | [tar.gz](https://github.com/idriskatar/F1/releases/download/v1.6.3/F1-Tracker-Linux-v1.6.3.tar.gz) |
| macOS | [F1-Tracker-v1.6.3.dmg](https://github.com/idriskatar/F1/releases/download/v1.6.3/F1-Tracker-v1.6.3.dmg) | [zip](https://github.com/idriskatar/F1/releases/download/v1.6.3/F1-Tracker-macOS-v1.6.3.zip) |
| Android | [F1-Tracker-Android-v1.6.3.apk](https://github.com/idriskatar/F1/releases/download/v1.6.3/F1-Tracker-Android-v1.6.3.apk) | — |

Windows `setup.exe` kullanıcı bazında kurulum yapar; Linux `.deb` için `sudo apt install ./f1-tracker_1.6.3_amd64.deb`; macOS `.dmg` uygulamayı Applications klasörüne sürükleyerek kurulur.

Tüm sürümler ve notlar: [GitHub Releases](https://github.com/idriskatar/F1/releases) · [CHANGELOG](CHANGELOG.md)

## Bu pakette

- Jolpica ile sezon takvimi, son yarış sınıflandırması ve pilot/takım puan durumu.
- Ana sayfada sıradaki yarış, geri sayım, sıradaki seans, son yarış podyumu ve şampiyona ilk 3 özeti (gerçek Jolpica verisi).
- Takvimdeki bir yarışa dokununca açılan detay ekranı: yarış sınıflandırması (grid, tur, en hızlı tur, puan), sıralama turları (Q1/Q2/Q3), sprint hafta sonlarında sprint sonuçları ve o yarıştan sonraki pilot/takım puan durumu. Yarış henüz yapılmadıysa hafta sonu programı gösterilir.
- Haberler sekmesi ve ana sayfada en yeni 3 haber: TRF1.net ve Motorsport.com Türkiye RSS akışları. Yalnızca başlık, kısa özet, kaynak adı ve tarih gösterilir; haber tarayıcıda kaynağında açılır. Kaynak filtresi, kaynak başına hata bildirimi ve çevrimdışı önbellek vardır.
- Replay sekmesinde bitmiş yarışlar pist haritası üzerinde yeniden oynatılır: 20 aracın konumu, oynat/duraklat, ±10 sn, 1×–60× hız ve zaman çubuğu; seçili pilot için hız, vites, gaz, fren, DRS ve son 60 sn hız grafiği; pit stop listesi. Zaman çubuğunda tur sınırları, seçili pilotun pit stopları ve safety car / VSC / kırmızı bayrak dönemleri işaretlenir; tur etiketine dokunarak ya da önceki/sonraki tur düğmeleriyle tura atlanabilir. Alt panelde ayrıca seçili pilotun tur süreleri grafiği ve olay akışı (ceza dahil) bulunur; üstteki düğme tüm pilotların lastik stratejisini açar. Sıralama listesi lidere ya da öndekine farkı gösterir; "Karşılaştır" sayfası iki pilotun hız ve gaz eğrilerini üst üste çizer. Geniş ve alçak ekranlarda (yatay mod) harita solda, pilot paneli sağda yer alır. Haritanın üstünde tek satırlık pist hava durumu (yağış, hava/pist sıcaklığı, nem, rüzgâr) görünür. Alt panelde canlı sıralama listesi (her pilotun yanında o anki lastik simgesi, en hızlı tur sahibinde kronometre), seçili pilot için dairesel gösterge (hız, gaz, fren, devir, vites), son tur süresi, lastik bileşeni/yaşı ve S1/S2/S3 sektör çubukları bulunur. Veri OpenF1'den GitHub Actions ile üretilip bu deponun `data/replay/` klasöründen indirilir.
- API tarih ve saatlerinin cihazın yerel saat diliminde gösterilmesi.
- Son başarılı API yanıtlarının SQLite üzerinde çevrimdışı önbelleği.
- Yükleniyor, hata/yeniden dene, önbellek ve henüz sonuç yok durumları.
- Koyu, açık ve Pitwall temaları; tercih cihazda saklanır.
- Sol üstteki hamburger menüsünden açılan Ayarlar ekranında koyu, açık ve Pitwall temaları.
- Hakkında (geliştirici: İdris KATAR), Gizlilik politikası ve Flutter'ın açık kaynak lisans ekranı.
- Android sistem geri tuşu; açık yarış detayını kapatır, ana sekmeye döner ve Ana sayfadayken uygulamadan çıkar.
- Beş sekmeli gezinme: telefonlarda alt gezinme çubuğu, masaüstünde (≥900 px) solda genişletilmiş gezinme rayı. Ayarlar, Hakkında, Gizlilik ve lisanslar menüden açılır.
- Masaüstü klavye kısayolları: `Ctrl/Cmd+1..5` sekmeler, `Ctrl/Cmd+M` menü, `Esc` açık sayfayı kapatır ya da ana sayfaya döner. Pencere 1400×900 açılır, en az 1000×650 boyuta küçültülebilir.
- Geniş ekran düzeni: ana sayfada yarış kartları ve puan durumları yan yana; takvim, haberler ve sonuçlarda iki sütunlu listeler; Ayarlar ekranında alt alta kartlar (MIT lisans metniyle, ayrı lisans ekranı yok). Mobil düzen aynen korunur.
- Ücretsiz GitHub Actions Android APK, imzasız iOS simülatör ve Windows/Linux/macOS masaüstü derlemeleri.

## Gerçek veri ve örnek alanlar

Takvim ile Sonuçlar sekmeleri `https://api.jolpi.ca/ergast/f1/` üzerinden gerçek API verisi yükler. Ekranlar API yanıtını veya çevrimdışı SQLite kopyasını kaynağıyla etiketler. Jolpica bir yarış sonucu henüz yayımlamadıysa sonuç tablosu yerine “henüz yayımlanmış sonuç yok” gösterilir. Replay sekmesi, GitHub Actions'ın OpenF1 verisinden ürettiği hazır dosyaları bu deponun `data/replay/` klasöründen (raw.githubusercontent.com) indirir; uygulama OpenF1'e doğrudan bağlanmaz.

Haberler şu herkese açık Türkçe RSS akışlarından gelir:

| Kaynak | Akış |
| --- | --- |
| TRF1.net | `https://trf1.net/feed/` |
| Motorsport.com Türkiye | `https://tr.motorsport.com/rss/f1/news/` |

Bu akışlar üçüncü tarafların hizmetidir; adres veya kullanım koşulları değişebilir, bir kaynak yanıt vermezse uygulama o kaynağı uyarıyla işaretler ve varsa önbellekteki haberleri gösterir. Kaynakların kendi kullanım koşullarını (özellikle uygulamayı dağıtmayı düşünürseniz) ayrıca kontrol edin.

Jolpica ücretsiz ve açık kaynaklıdır; bağımsız gönüllülerce işletilir. Erişim sınırı, kesinti veya API değişikliği olabilir. Uygulama bu durumlarda varsa yerel önbelleği kullanır. Uygulamaya ücretli API, abonelik veya zorunlu hosting eklenmemiştir.

OpenF1, 2023 sezonundan itibaren tarihsel seans verisini kimlik doğrulama olmadan sunar. Replay verisini bu API'den uygulama değil, GitHub Actions iş akışı (`tool/replay/build_replay.py`) üretir; yalnızca bitmiş yarışlar işlenir. Kaynak/API koşulları değişebilir. Ayrıntılar için [docs/replay-pipeline.md](docs/replay-pipeline.md).

## Bilgisayarda çalıştırma

Gereksinimler: Flutter stable 3.50+ (Dart 3.14+). Platform runner klasörleri bu pakette bulunmayabilir; kullanacağınız platformlar için proje kökünde bir kez üretin. `flutter create` mevcut dosyaların üzerine yazmaz.

### Masaüstü (Windows, Linux, macOS)

```bash
flutter create --project-name f1_tracker --org com.idriskatar --platforms=windows,linux,macos .
python3 tool/configure_app_name.py
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Masaüstü desteği güncel Flutter stable sürümünde varsayılan olarak açıktır. `flutter pub get` SDK sürümü uyarısı verirse `flutter upgrade` ile stable kanalı güncelleyin.

`flutter run -d linux` veya `flutter run -d macos` ile diğer platformlarda çalıştırın. Sürüm derlemeleri:

```bash
flutter build windows --release   # build/windows/x64/runner/Release/
flutter build linux --release     # build/linux/x64/release/bundle/
flutter build macos --release     # build/macos/Build/Products/Release/
```

- Windows derlemesi Visual Studio 2022'de “Desktop development with C++” iş yükünü gerektirir.
- Linux derlemesi ve testleri `clang`, `cmake`, `ninja-build`, `pkg-config` ve GTK/X11 geliştirme dosyalarını gerektirir: `sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev libx11-dev libxi-dev liblzma-dev`.
- macOS derlemesi yalnızca macOS + Xcode ile yapılabilir; yerel/ad-hoc imzalı derleme çalışır, dağıtım için Apple imzası gerekir. Yapılandırma betiği macOS sandbox için giden ağ iznini (`com.apple.security.network.client`) ekler.
- Windows'ta betiği `python tool/configure_app_name.py` ile çalıştırın.
- Masaüstünde SQLite `sqflite_common_ffi` ile, önbellek ve replay dosyaları işletim sisteminin uygulama destek dizininde tutulur.

### Mobil (Android, iOS)

```bash
flutter create --project-name f1_tracker --platforms=android,ios .
python3 tool/configure_app_name.py
flutter pub get
flutter analyze
flutter test
flutter run
```

iOS derlemesi için macOS ve Xcode gerekir. Yerel Android sürüm derlemesi: `flutter build apk --release`.

Kurulumda görünen uygulama adı **F1 Tracker** olarak yapılandırılır (Android etiketi, iOS görünen adı, Windows pencere/ürün adı, Linux pencere başlığı ve macOS ürün adı). GitHub Actions bu ayarı derleme sırasında uygular; runner klasörlerini yeni oluşturduğunuzda yukarıdaki yapılandırma betiğini çalıştırın. Dart paket adı ve import yolu `f1_tracker` olarak kalır.

## GitHub’a yükleme ve commit

1. Bu paketteki `f1-tracker-jolpica-mobile.zip` dosyasını bilgisayarda yeni bir klasöre çıkarın. GitHub deponuzun `main` dalında başlangıç projesi zaten varsa, çıkarılmış dosyaları deponun köküne kopyalayın ve mevcut dosyaların üzerine yazın. `android/`, `ios/`, `windows/`, `linux/` ve `macos/` klasörleri yerelde oluşturulmuşsa bunları da ekleyin; yoksa Actions kendisi üretir.
2. GitHub’da deponuzu açın. **Add file → Upload files** seçip proje kökündeki dosya ve klasörleri yükleme alanına bırakın. Gizli `.github` klasörünün içindeki `.github/workflows/build-mobile.yml` ve `.github/workflows/build-desktop.yml` dosyalarının da eklendiğini kontrol edin. Web arayüzü gizli klasörü yüklemiyorsa **Add file → Create new file** seçin, dosya yolu alanına ilgili workflow yolunu yazın ve bu dosyanın içeriğini projedeki aynı adlı workflow’dan kopyalayın.
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

Actions adımları Android’de `flutter analyze` ve `flutter test` çalıştırır, ardından release APK üretir. iOS işi imzasız simülatör uygulaması oluşturur; App Store paketi değildir.

Masaüstü için **F1 Tracker Desktop Build** iş akışı ayrı ayrı Windows, Linux ve macOS release derlemeleri üretir:

1. **Actions → F1 Tracker Desktop Build → Run workflow** ile başlatın (veya `main` dalına commit gönderin).
2. Artifact’lar: `f1-tracker-windows.zip` (klasörü açıp `f1_tracker.exe` çalıştırın), `f1-tracker-linux.tar.gz` (`tar -xzf` sonrası `bundle/f1_tracker`) ve `f1-tracker-macos.zip` (açıp `F1 Tracker.app` çalıştırın).
3. İndirilen masaüstü uygulamaları imzasızdır; macOS’ta ilk açılışta sağ tık → **Open** gerekebilir, Windows SmartScreen uyarısı gösterebilir.

GitHub’ın Actions dakikaları ve artifact saklama politikaları hesabın planına/limitlerine bağlı olabilir.

## Teknik yapı

- `lib/core/models`: Jolpica, haber ve replay modelleri ve formatlama.
- `lib/data/remote/jolpica_repository.dart`: HTTP, toleranslı yanıt ayrıştırma, hata yönetimi ve SQLite önbellek fallback’i; tur bazlı sonuç/sıralama/sprint/puan durumu sorguları.
- `lib/data/remote/replay_repository.dart` ve `lib/features/replay/`: hazır replay dosyalarını indirir ve diskte önbellekler; pist haritası, oynatıcı, telemetri paneli ve pit listesi.
- `tool/replay/` ve `.github/workflows/build-replay-data.yml`: OpenF1'den replay dosyalarını üreten Python hattı ve zamanlanmış iş akışı.
- `lib/features/settings/settings_screen.dart`, `lib/features/more/more_screen.dart` ve `lib/core/theme/app_theme.dart`: tema tercihleri, hakkında/gizlilik/lisans sayfaları, sistem fontu ve renk paletleri.
- `lib/features/shell/app_shell.dart`: duyarlı sekme gezinmesi (alt çubuk / masaüstü yan rayı), masaüstü klavye kısayolları ve Android sistem geri tuşunun sekme/detay davranışı.
- `lib/core/models/news_models.dart` ve `lib/data/remote/news_repository.dart`: RSS/Atom ayrıştırma, kaynakları birleştirme/sıralama, kaynak bazlı hata ve önbellek.
- `lib/features/calendar/race_detail_screen.dart`: yarış detay ekranı.
- `test/`: sahte HTTP istemcisi ve sabit saatle model, repository ve ekran testleri (`test/support/fakes.dart`).
- `lib/data/local/app_dirs.dart` ve `lib/data/local/local_store.dart`: mobilde `sqflite`, masaüstünde `sqflite_common_ffi` arka ucuyla platform yerel SQLite cache ve ortak veri dizini.
- `lib/main.dart`: masaüstünde `window_manager` ile pencere boyutu/başlığı ve SQLite FFI başlatması; mobilde yalnızca normal uygulama başlangıcı.
- `lib/features`: premium temalı mobil ve masaüstü ekranlar.
- `.github/workflows/build-mobile.yml` ve `.github/workflows/build-desktop.yml`: Android/iOS simülatör ve Windows/Linux/macOS CI işleri.

## Sonraki işler

- Platform cihaz derlemelerini ve entegrasyon testlerini genişletmek; replay hattını gerçek OpenF1 verisiyle doğrulamak.

F1, Formula 1 ve takım/pilot adları ilgili sahiplerinin markalarıdır. Bu bağımsız kişisel proje Formula 1, FIA veya herhangi bir takımla bağlantılı değildir.
