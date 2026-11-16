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
python -m unittest discover -s tool/replay -p "test_*.py" -v     # ağ gerektirmez
```

## Hangi OpenF1 uçları kullanılıyor?

| Uç | Ne için |
|---|---|
| `sessions` | Yarış seansını bulmak, takvim ve bitiş zamanı |
| `drivers` | Pilot kodu, adı, takımı, takım rengi |
| `session_result` | Bitiş sırası (pilot listesi sıralaması) |
| `laps` | Tur başlangıç/bitiş zamanları, tur süresi, tur sayacı |
| `pit` | Pit girişi ve pit şeridi süresi |
| `location` | Her pilotun x, y konumu (pist üzerinde hareket) |
| `car_data` | Hız, vites, gaz, fren, DRS |

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
      "x": [...], "y": [...],                 # veri yoksa null
      "speed", "gear", "throttle", "brake", "drs"     # isteğe bağlı kanallar
  }],
  "pits": [{"driver": "VER", "lap": 12, "in": 1234.5, "out": 1257.0, "pitLane": 22.5}]
}
```

Biçim değişirse **iki tarafta da** `version` artırılmalıdır; eski uygulama yeni dosyayı "güncelleyin"
mesajıyla reddeder. Fixture'ı yeniden üretmek için:
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
