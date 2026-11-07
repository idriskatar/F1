import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/live_timing_model.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/f1_live_pulse_client.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.isActive});
  final bool isActive;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _keyStore = RapidApiKeyStore();
  final _api = F1LivePulseClient();
  final _keyController = TextEditingController();
  Timer? _timer;
  String? _apiKey;
  String? _error;
  List<LiveTimingDriver> _drivers = const [];
  DateTime? _updatedAt;
  bool _checkingKey = false;
  bool _loading = false;
  bool _busy = false;
  bool _showKeyForm = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) unawaited(_activate());
  }

  @override
  void didUpdateWidget(covariant LiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      unawaited(_activate());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _activate() async {
    if (_apiKey != null) {
      _startPolling();
      return;
    }
    setState(() => _checkingKey = true);
    try {
      final savedKey = await _keyStore.read();
      if (!mounted) return;
      setState(() {
        _apiKey = savedKey?.trim().isEmpty == true ? null : savedKey;
        _checkingKey = false;
        _showKeyForm = savedKey == null || savedKey.isEmpty;
      });
      if (_apiKey != null && widget.isActive) _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingKey = false;
        _error = 'API anahtarı güvenli depodan okunamadı.';
        _showKeyForm = true;
      });
    }
  }

  void _startPolling() {
    if (_timer != null || _apiKey == null) return;
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_busy && widget.isActive) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    final key = _apiKey;
    if (key == null || _busy) return;
    _busy = true;
    if (_drivers.isEmpty && mounted) setState(() => _loading = true);
    try {
      final drivers = await _api.fetchTimingData(key);
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _updatedAt = DateTime.now();
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      _busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'RapidAPI anahtarını gir.');
      return;
    }
    setState(() {
      _checkingKey = true;
      _error = null;
    });
    try {
      await _keyStore.save(key);
      if (!mounted) return;
      setState(() {
        _apiKey = key;
        _showKeyForm = false;
        _checkingKey = false;
      });
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingKey = false;
        _error = 'Anahtar güvenli depoya kaydedilemedi.';
      });
    }
  }

  Future<void> _forgetKey() async {
    _timer?.cancel();
    _timer = null;
    try {
      await _keyStore.delete();
    } catch (_) {
      if (mounted) setState(() => _error = 'Kayıtlı anahtar silinemedi.');
      return;
    }
    if (!mounted) return;
    _keyController.clear();
    setState(() {
      _apiKey = null;
      _drivers = const [];
      _updatedAt = null;
      _error = null;
      _showKeyForm = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _keyController.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(children: [
            Expanded(child: Text('Canlı', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900))),
            if (_apiKey != null)
              IconButton(
                tooltip: 'API anahtarını değiştir',
                onPressed: _forgetKey,
                icon: const Icon(Icons.key_rounded),
              ),
            IconButton(tooltip: 'Şimdi yenile', onPressed: _apiKey == null ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 5),
          const Text('F1 Live Pulse • canlı zamanlama', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          if (_checkingKey && _apiKey == null)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (_apiKey == null || _showKeyForm)
            _keySetupCard()
          else ...[
            _connectionStatus(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorCard(),
            ],
            const SizedBox(height: 14),
            if (_loading && _drivers.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_drivers.isEmpty && _error == null)
              _emptyState()
            else if (_drivers.isNotEmpty) ...[
              _tableHeader(),
              const SizedBox(height: 8),
              ..._drivers.map(_driverCard),
            ],
            const SizedBox(height: 8),
            const Text('Otomatik yenileme: 30 saniye • yalnızca bu sekme açıkken', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 10)),
          ],
        ],
      ),
    ),
  );

  Widget _keySetupCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.lock_outline_rounded, color: AppColors.red),
      const SizedBox(height: 10),
      const Text('RapidAPI anahtarı gerekli', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('RapidAPI hesabındaki F1 Live Pulse anahtarını buraya gir. Anahtar bu cihaza güvenli biçimde kaydedilir; uygulama kaynak koduna eklenmez.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 14),
      TextField(
        controller: _keyController,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(labelText: 'X-RapidAPI-Key', border: OutlineInputBorder(), prefixIcon: Icon(Icons.key_rounded)),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: AppColors.amber, fontSize: 12)),
      ],
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _checkingKey ? null : _saveKey, icon: const Icon(Icons.lock), label: const Text('Güvenli kaydet ve bağlan'))),
    ]),
  );

  Widget _connectionStatus() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Icon(_error == null && _drivers.isNotEmpty ? Icons.sensors_rounded : Icons.cloud_outlined, size: 17, color: _error == null && _drivers.isNotEmpty ? AppColors.green : AppColors.amber),
      const SizedBox(width: 8),
      Expanded(child: Text(_error == null && _drivers.isNotEmpty ? 'Veri alındı • ${_formatTime(_updatedAt)}' : 'F1 Live Pulse bağlantısı', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
      if (_loading) const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
    ]),
  );

  Widget _errorCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.amber.withValues(alpha: .35))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 18),
      const SizedBox(width: 9),
      Expanded(child: Text(_drivers.isEmpty ? _error! : 'Güncelleme alınamadı: $_error. Son alınan zamanlama gösteriliyor.', style: const TextStyle(color: AppColors.muted, fontSize: 12))),
      if (_drivers.isEmpty) IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Yeniden dene'),
    ]),
  );

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      const Icon(Icons.hourglass_empty_rounded, color: AppColors.muted, size: 30),
      const SizedBox(height: 10),
      const Text('Şu anda sürücü verisi yok', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('Aktif bir seans yoksa veya sağlayıcı henüz veri yayımlamadıysa tablo boş kalabilir.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 8),
      TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Yeniden dene')),
    ]),
  );

  Widget _tableHeader() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10),
    child: Row(children: [
      SizedBox(width: 38, child: Text('POS', style: _headerStyle)),
      SizedBox(width: 40, child: Text('NO', style: _headerStyle)),
      Expanded(child: Text('PİLOT / TAKIM', style: _headerStyle)),
      SizedBox(width: 72, child: Text('EN İYİ TUR', textAlign: TextAlign.end, style: _headerStyle)),
    ]),
  );

  Widget _driverCard(LiveTimingDriver driver) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      SizedBox(width: 30, child: Text(driver.position == 0 ? '—' : driver.position.toString().padLeft(2, '0'), style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 13))),
      SizedBox(width: 38, child: Text(driver.racingNumber, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700))),
      Container(width: 3, height: 34, margin: const EdgeInsets.only(right: 9), decoration: BoxDecoration(color: Color(driver.teamColor), borderRadius: BorderRadius.circular(3))),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(driver.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))), Text(driver.code, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w900, fontSize: 10))]),
        const SizedBox(height: 3),
        Row(children: [Expanded(child: Text(driver.team, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10))), _driverStatus(driver)]),
      ])),
      const SizedBox(width: 5),
      SizedBox(width: 68, child: Text(driver.bestLapTime, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10))),
    ]),
  );

  Widget _driverStatus(LiveTimingDriver driver) {
    final label = driver.retired ? 'OUT' : driver.inPit ? 'PIT' : driver.stopped ? 'STOP' : driver.compound;
    if (label == '—') return const SizedBox.shrink();
    final color = driver.retired || driver.stopped ? AppColors.amber : AppColors.muted;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(5)), child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)));
  }
}

const _headerStyle = TextStyle(color: AppColors.muted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8);

String _formatTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}
