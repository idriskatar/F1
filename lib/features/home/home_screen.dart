import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/demo_notice.dart';
import '../../shared/widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 30,
                decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.flag_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('F1 TRACKER', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
              const Spacer(),
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
            ],
          ),
          const SizedBox(height: 18),
          const DemoNotice(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF292D36), Color(0xFF15181F), Color(0xFF351412)],
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEXT RACE', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 10),
                const Text('Grand Prix', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
                const Text('Takvim verisi bağlandığında burada görünecek', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CountdownUnit(value: '--', label: 'GÜN'),
                    _CountdownUnit(value: '--', label: 'SAAT'),
                    _CountdownUnit(value: '--', label: 'DK'),
                    _CountdownUnit(value: '--', label: 'SN'),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: AppColors.border),
                const Row(children: [
                  Icon(Icons.schedule, color: AppColors.red, size: 17),
                  SizedBox(width: 8),
                  Text('Seans programı senkronizasyon bekliyor', style: TextStyle(fontSize: 12)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionTitle('Son seans', action: 'Sonuçlar'),
          const SizedBox(height: 12),
          const _InfoTile(icon: Icons.timer_outlined, title: 'Henüz seans verisi yok', subtitle: 'İlk başarılı veri senkronizasyonundan sonra burada görünecek.'),
          const SizedBox(height: 22),
          const SectionTitle('Son haberler', action: 'Tüm haberler'),
          const SizedBox(height: 12),
          const _InfoTile(icon: Icons.newspaper, title: 'Haber akışı hazırlanıyor', subtitle: 'Ücretsiz RSS kaynakları bağlandığında haberler listelenecek.'),
          const SizedBox(height: 22),
          const SectionTitle('Şampiyona'),
          const SizedBox(height: 12),
          const _InfoTile(icon: Icons.emoji_events_outlined, title: 'Puan durumu bekleniyor', subtitle: 'Jolpica verileriyle pilot ve takım puanları gösterilecek.'),
        ],
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  const _CountdownUnit({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(fontSize: 9, color: AppColors.muted, letterSpacing: 1.2)),
  ]);
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.red)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ])),
    ]),
  );
}
