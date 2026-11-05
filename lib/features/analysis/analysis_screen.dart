import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/demo_notice.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Analiz', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Tur temposu, lastik ve strateji', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          const DemoNotice(text: 'Grafikler gerçek seans verisi bağlandığında üretilecek.'),
          const SizedBox(height: 16),
          const _Panel(title: 'Tur zamanı analizi', subtitle: 'Pilotların tur bazında tempo karşılaştırması'),
          const SizedBox(height: 12),
          const _Panel(title: 'Lastik stratejisi', subtitle: 'Hamur, stint uzunluğu ve lastik yaşı'),
          const SizedBox(height: 12),
          const _Panel(title: 'Sektör karşılaştırması', subtitle: 'S1, S2 ve S3 en iyi dereceleri'),
          const SizedBox(height: 12),
          const _Panel(title: 'Pit stop analizi', subtitle: 'Pit girişleri, çıkışları ve duruş süreleri'),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const SizedBox(height: 16),
      Container(height: 90, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.show_chart_rounded, color: AppColors.red, size: 34)),
      const SizedBox(height: 8),
      const Text('Veri bekleniyor', style: TextStyle(color: AppColors.muted, fontSize: 10)),
    ]),
  );
}
