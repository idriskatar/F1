import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.themeId, required this.onThemeChanged});

  final String themeId;
  final ValueChanged<String> onThemeChanged;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Daha fazla', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Uygulama tercihleri ve bilgiler', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            _MoreTile(
              icon: Icons.settings_outlined,
              title: 'Ayarlar',
              subtitle: 'Tema ve canlı veri API anahtarı',
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
              title: 'Açık kaynak lisansları',
              subtitle: 'Uygulamada kullanılan paketler',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'F1 Tracker',
                applicationVersion: '0.1.0',
              ),
            ),
          ],
        ),
      );
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
            Text('Sürüm 0.1.0', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            const _InfoSection(
              title: 'Geliştirici',
              body: 'İdris KATAR',
            ),
            const _InfoSection(
              title: 'Uygulama hakkında',
              body: 'F1 Tracker; yarış takvimi, sonuçlar, haberler ve seans bilgilerini tek yerde sunan bağımsız bir kişisel projedir. Formula 1, FIA veya takımlarla bağlantısı yoktur.',
            ),
            const _InfoSection(
              title: 'Veri kaynakları',
              body: 'Takvim ve sonuçlar Jolpica, seans analizi OpenF1, canlı zamanlama ise F1 Live Pulse (RapidAPI) üzerinden alınır. Haberler ilgili RSS yayıncılarından yüklenir.',
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
              title: 'API anahtarı',
              body: 'F1 Live Pulse için girdiğin RapidAPI anahtarı cihazın güvenli depolamasında tutulur ve yalnızca RapidAPI isteğinde kimlik doğrulama başlığı olarak gönderilir. Anahtarı Ayarlar bölümünden silebilirsin.',
            ),
            _InfoSection(
              title: 'Üçüncü taraf hizmetleri',
              body: 'Takvim/sonuç, seans analizi, canlı zamanlama ve haber istekleri sırasıyla Jolpica, OpenF1, RapidAPI/F1 Live Pulse ve RSS yayıncılarına gider. Bu hizmetler bağlantı bilgilerini kendi politikalarına göre işleyebilir.',
            ),
            _InfoSection(
              title: 'Yerel veriler ve iletişim',
              body: 'RapidAPI anahtarını Ayarlar ekranından silebilirsin. Tema tercihi ve çevrimdışı önbellek cihazda tutulur; uygulama verileri işletim sisteminin uygulama depolama ayarlarından temizlenebilir. Gizlilik soruları için geliştirici: İdris KATAR.',
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
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 7),
          Text(body, style: TextStyle(color: AppColors.muted, height: 1.5)),
        ]),
      );
}
