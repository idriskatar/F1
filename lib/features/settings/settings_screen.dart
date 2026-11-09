import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.themeId, required this.onThemeChanged});

  final String themeId;
  final ValueChanged<String> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Text('Uygulamanın görünümünü seç.', style: textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 22),
                Text('TEMA', style: textTheme.labelLarge?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                  child: Column(children: [
                    _ThemeOption(id: 'dark', selected: themeId == 'dark', title: 'Koyu', subtitle: 'F1 gece modu', icon: Icons.dark_mode_rounded, onTap: onThemeChanged),
                    const Divider(height: 1),
                    _ThemeOption(id: 'light', selected: themeId == 'light', title: 'Açık', subtitle: 'Gündüz görünümü', icon: Icons.light_mode_rounded, onTap: onThemeChanged),
                    const Divider(height: 1),
                    _ThemeOption(id: 'pitwall', selected: themeId == 'pitwall', title: 'Pitwall', subtitle: 'Koyu mavi yarış teması', icon: Icons.flag_rounded, onTap: onThemeChanged),
                  ]),
                ),
                const SizedBox(height: 14),
                Text('Yarış analizleri OpenF1’ın geçmiş verilerinden yüklenir. API anahtarı gerekmez.', style: textTheme.bodySmall?.copyWith(color: AppColors.muted, height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.id, required this.selected, required this.title, required this.subtitle, required this.icon, required this.onTap});

  final String id;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        selected: selected,
        onTap: () => onTap(id),
        leading: Icon(icon, color: AppColors.red),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
        trailing: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppColors.red : AppColors.muted),
      );
}
