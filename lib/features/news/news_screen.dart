import 'package:flutter/material.dart';
import '../../core/data/demo_data.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/demo_notice.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Haberler', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Paddock gündemi ve teknik gelişmeler', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          const DemoNotice(text: 'Bunlar haber değildir; RSS entegrasyonu için arayüz yer tutucularıdır.'),
          const SizedBox(height: 16),
          ...demoNewsTitles.asMap().entries.map((entry) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.article_outlined, color: AppColors.red, size: 28)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Kaynak bağlantısı ve yayın tarihi RSS entegrasyonuyla eklenecek.', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                const SizedBox(height: 8),
                const Text('KAYNAK BEKLENİYOR', style: TextStyle(color: AppColors.red, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ])),
            ]),
          )),
        ],
      ),
    );
  }
}
