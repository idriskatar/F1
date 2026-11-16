# Replay hattı

Yarış sonrası **konum + telemetri + pit stop** verisini FastF1'den üretir, küçük dosyalara çevirir ve
uygulamaya GitHub üzerinden sunar. Uygulama OpenF1'e hiç bağlanmaz.

```
GitHub Actions (build-replay-data.yml)
  └─ tool/replay/build_replay.py  ── FastF1 ──►  data/replay/index.json
                                                 data/replay/<yıl>/r<tur>-R.json.gz
Flutter (Menü ▸ Yarış replay)
  └─ ReplayRepository ── raw.githubusercontent.com ──► diskte önbellek ──► ReplayScreen
```

## Çalıştırma

**Actions'tan elle:** Actions ▸ *Build Replay Data* ▸ *Run workflow*. Yıl ve tur gir
(ör. `2026` / `22`), sprint için seansa `S` yaz. Alanları boş bırakırsan bitmiş ama işlenmemiş
yarışlar işlenir (en fazla 2).

**Otomatik:** Pazar ve Pazartesi her 3 saatte bir. Veri henüz yayınlanmamışsa betik uyarı verir
ve bir sonraki çalışmada yeniden dener (iş kırmızı yanmaz).

**Yerelde:**
```
pip install -r tool/replay/requirements.txt
python tool/replay/build_replay.py --year 2026 --round 22
python -m unittest discover -s tool/replay -p "test_*.py" -v     # ağ gerektirmez
```

## Dosya biçimi (version 1)

Şema `tool/replay/build_replay.py` dosyasının başındaki açıklamada tanımlıdır; Flutter karşılığı
`lib/core/models/replay_models.dart`. İkisi arasındaki uyumu `test/fixtures/replay_sample.json`
(Python tarafından üretilen sentetik seans) ve `test/core/replay_models_test.dart` korur.
Biçim değişirse **iki tarafta da** `version` artırılmalıdır; eski uygulama yeni dosyayı
"güncelleyin" mesajıyla reddeder.

Fixture'ı yeniden üretmek için: `python tool/replay/sample_data.py test/fixtures/replay_sample.json`

## Bilinen sınırlar

- **Pit süresi = pit şeridi süresi.** Giriş ile çıkış arasındaki süredir; lastik değişimindeki
  duruş süresi (ör. 2,4 sn) FastF1'de yok.
- **Konum örnekleme:** varsayılan 2 örnek/sn; arası uygulamada doğrusal ara değerlenir. Dar
  virajlarda köşe hafifçe kesilebilir. Gerekirse `--hz 4` (dosya yaklaşık 2 kat büyür).
- **Veri boşlukları tahmin edilmez.** 3 sn'den uzun boşluk ve veri bittikten sonrası `null` olur;
  araç o anlarda pistte çizilmez.
- **Lider tablosu yok** (bilinçli): konumdan türetilen sıralama güvenilir değil.
- **DRS:** FastF1 kodları 10/12/14 "açık" sayıldı (8 = açılabilir, 0/1 = kapalı). Bu eşleme gerçek
  veriyle doğrulanmalı.
- **Tamamlanmamış seans yayınlanmaz:** en az 10 pilot, %50 konum kapsaması ve 10 dk süre aranır
  (`validate_payload`).
- **Veri kaynağı:** FastF1 resmî olmayan F1 yayınlarını kullanır. Uygulamayı herkese
  dağıtmayı düşünürsen kullanım koşullarını ayrıca kontrol et.

## Sorun giderme

| Belirti | Olası neden |
|---|---|
| Uygulamada "Henüz hazır replay yok" | İlk Actions çalışması henüz yapılmadı / veri yayınlanmadı |
| Actions logunda `::warning:: ... işlenemedi` | FastF1 verisi henüz hazır değil; sonraki çalışmada yeniden denenir |
| `Seans çok kısa` / `Yeterli konum verisi olan pilot sayısı` | Kaynak veri eksik; elle yeniden çalıştırmayı birkaç saat sonra dene |
| Pist çizgisi bulunamadı | O seansta doğru (`IsAccurate`) tur ya da konum verisi yok |
