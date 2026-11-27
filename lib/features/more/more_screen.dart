import 'package:material_ui/material_ui.dart';

import '../../core/app_info.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/open_url.dart';
import '../../shared/widgets/responsive.dart';
import '../settings/settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.themeId, required this.onThemeChanged, this.embedded = false});

  final String themeId;
  final ValueChanged<String> onThemeChanged;

  /// Masaüstünde kabuğun içinde, ikinci bir Scaffold/AppBar olmadan gösterilir.
  final bool embedded;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) return _desktopContent();
    if (isDesktopLayout(context)) return _desktop(context);
    return _mobile(context);
  }

  /// Mobil: liste tarzı menü (Açık kaynak lisansları kaldırıldı).
  Widget _mobile(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Menü')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Uygulama tercihleri ve bilgiler', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: 'Ayarlar',
            subtitle: 'Tema ve görünüm',
            onTap: () => _open(context, SettingsScreen(themeId: themeId, onThemeChanged: onThemeChanged)),
          ),
          _MoreTile(
            icon: Icons.info_outline_rounded,
            title: 'Hakkında',
            subtitle: 'Uygulama ve geliştirici bilgileri',
            onTap: () => _open(context, const _AboutPage()),
          ),
          _MoreTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Gizlilik politikası',
            subtitle: 'Verilerin nasıl kullanıldığı',
            onTap: () => _open(context, const _PrivacyPage()),
          ),
          _MoreTile(
            icon: Icons.article_outlined,
            title: 'MIT Lisansı',
            subtitle: 'Açık kaynak kullanım koşulları',
            onTap: () => _open(context, const _MitLicensePage()),
          ),
          const _UpdateChecker(compact: true),
        ],
      ),
    ),
  );

  /// Masaüstü: başlıklar kartlar halinde alt alta dizilir.
  Widget _desktop(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Menü')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        children: [_desktopContent()],
      ),
    ),
  );

  Widget _desktopContent() => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red)),
                  const SizedBox(width: 10),
                  const Text('Ayarlar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Text('Uygulama tercihleri ve bilgiler', style: TextStyle(color: AppColors.muted)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.green.withValues(alpha: .08), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.green.withValues(alpha: .3))),
                    child: Text('v$appVersion', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 14),
                _settingsCard(),
                _aboutCard(),
                _privacyCard(),
                _licenseCard(),
                const _UpdateChecker(compact: false),
              ]),
            ),
          );

  Widget _cardShell({required IconData icon, required String title, required String subtitle, required String tag, required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.red.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.red, size: 19),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 11)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
          child: Text(tag, style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 16),
      ...children,
    ]),
  );

  Widget _settingsCard() => _cardShell(
    icon: Icons.settings_outlined,
    title: 'Ayarlar',
    subtitle: 'Tema ve görünüm',
    tag: 'TERCİHLER',
    children: [
      Row(children: [
        for (final option in _themeOptions) Expanded(child: _themeTile(option)),
      ]),
      const SizedBox(height: 12),
      Text(
        'Yarış replay verisi OpenF1 kaynaklıdır ve GitHub üzerinden indirilir. API anahtarı gerekmez.',
        style: TextStyle(color: AppColors.muted, fontSize: 10.5, height: 1.5),
      ),
    ],
  );

  List<_ThemeOption> get _themeOptions => const [
    _ThemeOption('dark', 'Koyu', 'F1 gece modu', Icons.dark_mode_rounded),
    _ThemeOption('light', 'Açık', 'Gündüz görünümü', Icons.light_mode_rounded),
    _ThemeOption('pitwall', 'Pitwall', 'Koyu mavi tema', Icons.flag_rounded),
  ];

  Widget _themeTile(_ThemeOption option) {
    final selected = themeId == option.id;
    return InkWell(
      onTap: () => onThemeChanged(option.id),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.red.withValues(alpha: .09) : AppColors.surface2,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? AppColors.red : AppColors.border),
        ),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: option.color, border: Border.all(color: AppColors.border))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(option.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(option.subtitle, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 10)),
          ])),
          if (selected) Icon(Icons.check_circle, color: AppColors.red, size: 16),
        ]),
      ),
    );
  }

  Widget _aboutCard() => _cardShell(
    icon: Icons.info_outline_rounded,
    title: 'Hakkında',
    subtitle: 'Uygulama ve geliştirici bilgileri',
    tag: 'BİLGİ',
    children: [
      Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.flag_rounded, color: Colors.white, size: 24)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('F1 Tracker', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text('Sürüm 0.1.0', style: TextStyle(color: AppColors.muted, fontSize: 11)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.amber.withValues(alpha: .3))),
          child: Text('Resmî değildir', style: TextStyle(color: AppColors.amber, fontSize: 10)),
        ),
      ]),
      const SizedBox(height: 14),
      const _InfoSection(title: 'Geliştirici', body: 'İdris KATAR'),
      const _InfoSection(
        title: 'Uygulama hakkında',
        body: 'F1 Tracker; yarış takvimi, sonuçlar, haberler ve seans bilgilerini tek yerde sunan bağımsız bir kişisel projedir. Formula 1, FIA veya takımlarla bağlantısı yoktur.',
      ),
      const _InfoSection(
        title: 'Veri kaynakları',
        body: 'Takvim ve sonuçlar Jolpica üzerinden alınır. Yarış replay verisi OpenF1 kaynaklıdır; GitHub Actions ile üretilip bu projenin GitHub deposundan indirilir. Haberler ilgili RSS yayıncılarından yüklenir.',
      ),
    ],
  );

  Widget _privacyCard() => _cardShell(
    icon: Icons.privacy_tip_outlined,
    title: 'Gizlilik Politikası',
    subtitle: 'Verilerin nasıl kullanıldığı',
    tag: 'GİZLİLİK',
    children: const [
      _InfoSection(
        title: 'Toplanan bilgiler',
        body: 'Uygulama hesabı oluşturmaz ve uygulama tarafından analiz/izleme amacıyla kişisel bilgi toplanmaz. Tema tercihi ve son başarılı API yanıtları cihazda saklanır.',
      ),
      _InfoSection(
        title: 'Üçüncü taraf hizmetleri',
        body: 'Takvim ve sonuç istekleri Jolpica, replay istekleri GitHub (raw.githubusercontent.com), haber istekleri RSS yayıncılarına gider. Bu hizmetler bağlantı bilgilerini kendi politikalarına göre işleyebilir.',
      ),
      _InfoSection(
        title: 'Yerel veriler ve iletişim',
        body: 'Tema tercihi ve çevrimdışı önbellek cihazda tutulur; uygulama verileri işletim sisteminin uygulama depolama ayarlarından temizlenebilir. Gizlilik soruları için geliştirici: İdris KATAR.',
      ),
    ],
  );

  Widget _licenseCard() => _cardShell(
    icon: Icons.article_outlined,
    title: 'MIT Lisansı',
    subtitle: 'Açık kaynak kullanım koşulları',
    tag: 'LİSANS',
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Text(
          'MIT License\nCopyright (c) 2026 İdris KATAR\n\n'
          'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.\n\n'
          'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.',
          style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.6),
        ),
      ),
    ],
  );
}

class _ThemeOption {
  const _ThemeOption(this.id, this.title, this.subtitle, this.icon);
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  Color get color => switch (id) {
    'light' => const Color(0xFFF2F4F7),
    'pitwall' => const Color(0xFF07131B),
    _ => const Color(0xFF14171D),
  };
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: Icon(icon, color: AppColors.red),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hakkında')),
    body: SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Icon(Icons.sports_motorsports_rounded, size: 56, color: AppColors.red),
        const SizedBox(height: 16),
        Text('F1 Tracker', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Sürüm $appVersion', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 24),
        const _InfoSection(title: 'Geliştirici', body: 'İdris KATAR'),
        const _InfoSection(
          title: 'Uygulama hakkında',
          body: 'F1 Tracker; yarış takvimi, sonuçlar, haberler ve seans bilgilerini tek yerde sunan bağımsız bir kişisel projedir. Formula 1, FIA veya takımlarla bağlantısı yoktur.',
        ),
        const _InfoSection(
          title: 'Veri kaynakları',
          body: 'Takvim ve sonuçlar Jolpica üzerinden alınır. Yarış replay verisi OpenF1 kaynaklıdır; GitHub Actions ile üretilip bu projenin GitHub deposundan indirilir. Haberler ilgili RSS yayıncılarından yüklenir.',
        ),
      ]),
    ),
  );
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gizlilik politikası')),
    body: SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: const [
        _InfoSection(
          title: 'Toplanan bilgiler',
          body: 'Uygulama hesabı oluşturmaz ve uygulama tarafından analiz/izleme amacıyla kişisel bilgi toplanmaz. Tema tercihi ve son başarılı API yanıtları cihazda saklanır.',
        ),
        _InfoSection(
          title: 'Üçüncü taraf hizmetleri',
          body: 'Takvim ve sonuç istekleri Jolpica, replay istekleri GitHub (raw.githubusercontent.com), haber istekleri RSS yayıncılarına gider. Bu hizmetler bağlantı bilgilerini kendi politikalarına göre işleyebilir.',
        ),
        _InfoSection(
          title: 'Yerel veriler ve iletişim',
          body: 'Tema tercihi ve çevrimdışı önbellek cihazda tutulur; uygulama verileri işletim sisteminin uygulama depolama ayarlarından temizlenebilir. Gizlilik soruları için geliştirici: İdris KATAR.',
        ),
      ]),
    ),
  );
}

class _MitLicensePage extends StatelessWidget {
  const _MitLicensePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MIT Lisansı')),
    body: SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('MIT License', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Copyright (c) 2026 İdris KATAR', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 20),
        Text(
          'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software.\n\n'
          'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.',
          style: TextStyle(color: AppColors.muted, height: 1.6),
        ),
      ]),
    ),
  );
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      const SizedBox(height: 5),
      Text(body, style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 12)),
    ]),
  );
}

/// GitHub Releases üzerinden güncelleme kontrolü (mobil liste / masaüstü kart).
class _UpdateChecker extends StatefulWidget {
  const _UpdateChecker({required this.compact});
  final bool compact;

  @override
  State<_UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<_UpdateChecker> {
  bool _busy = false;

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    final info = await checkForUpdate();
    if (!mounted) return;
    setState(() => _busy = false);
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Güncel sürümdesiniz (v$appVersion)')));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Yeni sürüm: v${info.version}'),
        content: SingleChildScrollView(
          child: Text(info.notes.isEmpty ? 'Yeni sürüm yayımlandı.' : info.notes, style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Kapat')),
          FilledButton(
            onPressed: () async {
              await openExternalUrl(info.url);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('İndir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trailing = _busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
        : const Icon(Icons.chevron_right_rounded);
    if (widget.compact) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(Icons.system_update_rounded, color: AppColors.red),
          title: const Text('Güncellemeyi kontrol et', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('En son sürümü GitHub Releases üzerinden kontrol eder', style: TextStyle(fontSize: 11)),
          trailing: trailing,
          onTap: _check,
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: InkWell(
        onTap: _check,
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.red.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.system_update_rounded, color: AppColors.red, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Güncellemeyi kontrol et', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('En son sürümü GitHub Releases üzerinden kontrol eder', style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ])),
          trailing,
        ]),
      ),
    );
  }
}
