import 'package:material_ui/material_ui.dart';

/// Alt gezinme çubuğundan yan gezinme rayına geçilen genişlik.
const double desktopBreakpoint = 900;

/// Masaüstü düzeni mi kullanılıyor? (Geniş pencere / masaüstü cihaz)
bool isDesktopLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= desktopBreakpoint;
