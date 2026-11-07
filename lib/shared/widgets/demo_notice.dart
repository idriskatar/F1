import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key, this.text = 'Örnek arayüz verisi • Gerçek sonuç değildir'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: AppColors.amber, fontSize: 11))),
        ],
      ),
    );
  }
}
