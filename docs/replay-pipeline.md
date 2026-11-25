# Replay hattı

Yarış sonrası **konum + telemetri + pit stop** verisini **OpenF1 API'sinden** üretir, küçük dosyalara
çevirir ve uygulamaya GitHub üzerinden sunar. Uygulama OpenF1'e hiç bağlanmaz; yalnızca bu projenin
GitHub deposundaki hazır dosyaları indirir.

```
GitHub Actions (build-replay-data.yml)
  └─ tool/replay/build_replay.py ── OpenF1 API ──►  data/replay/index.json
                                                    data/replay/<yıl>/r<tur>-R.json.gz
Flutter (alt gezinmedeki Replay sekmesi)
  └─ ReplayRepository ── raw.githubusercontent.com ──► diskte önbellek ──► ReplayScreen
```

> Not: Bu hat önce FastF1 ile yazılmıştı, sonra OpenF1'e taşındı. `--cache` parametresi ve
> `.fastf1-cache` adı geçmişten kalma; OpenF1 kullanırken yerel önbellek kullanılmıyor.

## Çalıştırma

**Actions'tan elle:** Actions ▸ *Build Replay Data* ▸ *Run workflow*.

- Alanları **boş bırakırsan** bitmiş ama işlenmemiş en yeni yarışlar işlenir (bir seferde en fazla 2).
  Önerilen yol budur.
- **`refresh` kutusunu işaretlersen** `index.json`'daki mevcut tüm seanslar yeniden üretilir. Veri
  biçimine yeni alan eklendiğinde (ör. sıralama, sektör süreleri) eski dosyaları güncellemek için kullan.
  Bir yarış yenilenemezse eski dosyası korunur. OpenF1 yarış sıralaması kaymış ve yarış adı
  uyuşmuyorsa o dosyaya da dokunulmaz.
- Elle yarış seçmek istersen yıl ve tur gir (sprint için seansa `S`). Bu **tur numarası OpenF1'in
  kendi sıralamasıdır**: o yılın "Race" seanslarını başlangıç tarihine göre dizip n. yarışı alır.
  Uygulamanın takvimindeki (Jolpica) "Tur" numarasıyla veya resmî takvim numarasıyla uyuşmayabilir;
  iptal edilen yarışlar olan sezonlarda özellikle.

**Otomatik:** Pazar ve Pazartesi her 3 saatte bir (UTC). Veri henüz hazır değilse betik uyarı verir ve
bir sonraki çalışmada yeniden dener.

**Yerelde:**
```
pip install -r tool/replay/requirements.txt          # numpy, pandas, requests
python tool/replay/build_replay.py --latest
python tool/replay/build_replay.py --year 2026 --round 20
python tool/replay/build_replay.py --refresh                      # mevcut tüm dosyaları yeniden üret
python -m unittest discover -s tool/replay -p "test_*.py" -v     # ağ gerektirmez
```

## Hangi OpenF1 uçları kullanılıyor?

| Uç | Ne için |
|---|---|
| `sessions` | Yarış seansını bulmak, takvim ve bitiş zamanı |
| `drivers` | Pilot kodu, adı, soyadı, takımı, takım rengi |
| `session_result` | Bitiş sırası (pilot listesi sıralaması) |
| `laps` | Tur başlangıç/bitiş zamanları, tur süresi, S1/S2/S3 sektör süreleri, tur sayacı |
| `pit` | Pit girişi ve pit şeridi süresi |
| `location` | Her pilotun x, y konumu (pist üzerinde hareket) |
| `car_data` | Hız, devir (RPM), vites, gaz, fren, DRS |
| `position` | Yarış boyunca sıra değişimleri (canlı sıralama listesi) |
| `stints` | Lastik bileşeni, stint tur aralığı, stint başındaki lastik yaşı |
| `weather` | Hava ve pist sıcaklığı, nem, rüzgâr (hız, yön), yağış |
| `race_control` | Safety car, VSC, kırmızı bayrak ve ceza mesajları (olay akışı) |

`position`, `stints`, `weather` ve `race_control` **isteğe bağlıdır**: bu uçlardan biri alınamazsa betik uyarı verir ve o alanlar
olmadan devam eder (replay yine üretilir).

Betik her pilot için `location` ve `car_data` uçlarını ayrı çağırır (yaklaşık 40+ istek). İstek
hatalarında davranış: `429/500/502/503/504` için 4 deneme (artan bekleme), `404` **hata değil boş liste**
sayılır, zaman aşımı 60 sn. Veri önce `RawSession` ara temsiline çevrilir, tüm hesaplama bu temsil
üzerinden yapılır (testler bu yüzden ağ gerektirmez).

## Dosya biçimi (version 1)

Flutter karşılığı `lib/core/models/replay_models.dart`. İkisi arasındaki uyumu
`test/fixtures/replay_sample.json` (sentetik seans) ve `test/core/replay_models_test.dart` korur.

```
{
  "version": 1,
  "event": {"year", "round", "session", "name", "country", "circuit"},
  "hz": 2,                        # örnekleme sıklığı; i. örnek = i / hz saniye
  "duration": 5400.0,             # replay süresi (sn); t=0 yarış başlangıcı
  "totalLaps": 57,
  "lapStarts": [0.0, 95.2, ...],  # kazananın tur başlangıçları (sn) -> tur sayacı
  "track": {"x": [...], "y": [...]},          # pist çizgisi (en hızlı turdan)
  "drivers": [{
      "number", "code", "name", "team", "color", "position",
      "lastName": "Antonelli",                # isteğe bağlı
      "x": [...], "y": [...],                 # veri yoksa null
      "speed", "gear", "throttle", "brake", "drs", "rpm",   # isteğe bağlı kanallar
      "positionLog": [[0.0, 2], [31.5, 3]],   # [replay_sn, sıra]; yalnızca değişimler
      "laps": [[1, 0.0, 95.2, null, 31.0, 33.4], ...],   # [tur, başlangıç_sn, süre, s1, s2, s3]; bilinmeyen = null
      "stints": [["MEDIUM", 1, 18, 0], ["HARD", 19, null, 0]]   # [bileşen, ilk_tur, son_tur|null, başlangıç_yaşı]
  }],
  "pits": [{"driver": "VER", "lap": 12, "in": 1234.5, "out": 1257.0, "pitLane": 22.5}],
  "weather": [[0.0, 24.0, 38.0, 52, 12.0, 135, 0], ...],  # isteğe bağlı: [replay_sn, hava°C, pist°C, nem%, rüzgâr km/sa, rüzgâr yönü°, yağmur 0/1]
  "events": [[1520.0, "SC", 21, "SAFETY CAR DEPLOYED", 1710.0], [812.5, "PENALTY", 12, "5 SECOND TIME PENALTY FOR CAR 4 (NOR) ...", null]]
                                                         # isteğe bağlı: [replay_sn, tür, tur|null, mesaj, bitiş_sn|null]
}
```

Yeni alanlar **isteğe bağlıdır**: uygulama bunlar olmadan da dosyayı açar (sıralama listesi bitiş
sırasını gösterir, sektör çubukları gri kalır). Bu yüzden alan eklemek `version`'ı artırmayı gerektirmez;
eski dosyaları güncellemek için `refresh` çalıştırılır. Var olan bir alanın anlamı değişirse **iki tarafta
da** `version` artırılmalıdır; eski uygulama yeni dosyayı "güncelleyin" mesajıyla reddeder. Fixture'ı yeniden üretmek için:
`python tool/replay/sample_data.py test/fixtures/replay_sample.json`

## Bilinen sınırlar ve ilk çalıştırmada doğrulanacaklar

Gerçek OpenF1 yanıtıyla uçtan uca henüz denenmedi; aşağıdakilerin ilk gerçek çalıştırmada kontrol
edilmesi gerekir.

- **Kapsam:** OpenF1 tarihsel veriyi 2023 sezonundan itibaren sunar.
- **Zaman damgası:** OpenF1 damgaları kesirli saniyeli ve kesirsiz karışık gelebilir. Bu yüzden
  `format="ISO8601"` ile okunur; yoksa pandas biçimi ilk satırdan çıkarıp uymayan satırları sessizce
  siler.
- **Yarış başlangıcı:** 1. turun `date_start` değeri boş gelirse replay 2. turun başından başlar (ilk
  tur eksik kalır). Gerçek veride kontrol edilmeli.
- **Mini sektörler yok:** Pist üzerindeki renkli mini sektör parçaları OpenF1'in yarışlarda yayınlamadığı
  veriye dayanır; replay'de gösterilmez. S1/S2/S3 çubukları tam sektör sürelerinden hesaplanır.
- **Sektör renkleri:** Mor = o ana kadarki tüm pilotların en iyisi, yeşil = pilotun kendi en iyisi,
  sarı = daha yavaş, beyaz = süren sektör, gri = henüz bitmedi ya da süre boş. 1. turun 1. sektörü sık
  boş geldiği için ilk turda çubuklar gri kalabilir.
- **Hava durumu:** Haritanın üstündeki tek satırlık şerit `weather` kaydından beslenir. OpenF1 rüzgâr
  hızını m/s verir, betik km/sa'ye çevirir (×3,6). Yağış, OpenF1'in `rainfall` alanındaki 0/1 değerinden
  gelir. Rüzgâr yönü dosyada saklanır ama şu an ekranda gösterilmez. Ölçüm yoksa şerit hiç görünmez.
- **Olaylar (`events`):** `race_control` mesajlarından çıkarılır. Tür `SC`, `VSC`, `RED` ise kayıt bir
  *dönemdir* (son alan bitiş saniyesi) ve zaman çubuğunda renkli bant, harita köşesinde rozet olarak görünür;
  `PENALTY` tek bir andır (son alan `null`). Dönemler mesaj metninden türetilir: SC `SAFETY CAR DEPLOYED` ile
  açılır, `IN THIS LAP` duyurusundan sonraki ilk pist yeşil/clear bayrağında kapanır (5 dk içinde gelmezse duyuru
  anında); VSC `ENDING` mesajında; kırmızı bayrak ilk pist yeşil bayrağında ya da safety car'da kapanır.
  Kapanışı bulunamayan dönem yarış sonunda biter. Yarış başlamadan önceki olaylar atılır, mesajlar 140 karaktere
  kısaltılır. `SERVED` / `NO FURTHER` içeren ceza mesajları olay sayılmaz. Uç boşsa `events` yazılmaz ve
  uygulamada "Olaylar" sayfası görünmez.
- **Lastik ve en hızlı tur simgeleri:** Sıralama listesindeki lastik simgesi, pilotun o an süren turuna
  denk gelen `stints` kaydından; kronometre, o ana kadar tamamlanan en hızlı turun sahibinden gelir.
  Tur bilgisi henüz yokken (yarışın ilk anları) 1. tur kabul edilir.
- **Sıralama:** `position` ucundan gelir (konumdan türetilmez). Uç boşsa liste "BİTİŞ SIRASI" gösterir.
- **Pit alanları:** Betik `pit` kaydındaki `date` alanını pit girişi, `pit_duration` alanını pit şeridi
  süresi kabul eder. OpenF1 alan adlarını değiştirdiyse `pitLane` boş (`null`) çıkar.
- **Pit süresi = pit şeridi süresi.** Lastik değişimindeki duruş süresi değildir.
- **İstek sınırı:** Kaynaklar sınırlar konusunda çelişiyor. Çok sayıda 429 görürsen istekler arası
  bekleme artırılmalı (`time.sleep(0.1)`).
- **Konum örnekleme:** varsayılan 2 örnek/sn; arası uygulamada doğrusal ara değerlenir. Dar virajlarda
  köşe hafifçe kesilebilir. Gerekirse `--hz 4` (dosya yaklaşık 2 kat büyür).
- **Veri boşlukları tahmin edilmez.** 3 sn'den uzun boşluk ve veri bittikten sonrası `null` olur;
  araç o anlarda pistte çizilmez.
- **Lider tablosu yok** (bilinçli): konumdan türetilen sıralama güvenilir değil.
- **DRS:** 10/12/14 "açık" sayılır (8 = açılabilir, 0/1 = kapalı).
- **Tamamlanmamış seans yayınlanmaz:** en az 10 pilot, %50 konum kapsaması ve 10 dk süre aranır
  (`validate_payload`).
- **Veri kaynağı:** OpenF1'in kullanım koşullarını, uygulamayı herkese dağıtmayı düşünürsen ayrıca
  kontrol et.

## Sorun giderme

`--latest` modu bir yarışı işleyemezse **hata vermez, sarı uyarı yazıp yeşil biter** (zamanlanmış
çalışmalar kırmızı yanmasın diye). Bu yüzden "çalışma başarılı ama veri yok" durumunda önce çalışma
sayfasının üstündeki **Annotations** bölümüne ya da `Build replay data` adımının log'una bak.

| Belirti | Olası neden |
|---|---|
| Uygulamada "Henüz hazır replay yok" | Çalışma henüz veri üretmedi; Annotations'taki uyarıya bak |
| `... islenemedi: Pilot listesi henüz yayinlanmadi` | OpenF1 seans verisini henüz yayınlamadı; sonraki çalışmada yeniden denenir |
| `Tur verileri henüz yayinlanmadi` | Aynı: veri henüz hazır değil |
| `... tur bulunamadi (toplam N tur)` | Elle girilen tur numarası OpenF1 sıralamasında yok; alanları boş bırakıp `--latest` kullan |
| `Seans çok kısa` / `Yeterli konum verisi olan pilot sayısı` | Kaynak veri eksik; birkaç saat sonra yeniden dene |
| `Pist cizgisi icin konum verisi bulunamadi` | `location` verisi boş ya da zaman damgaları okunamadı |
| Push başarısız | Settings ▸ Actions ▸ General ▸ Workflow permissions ▸ *Read and write* |
