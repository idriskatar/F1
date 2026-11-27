import 'package:material_ui/material_ui.dart';

/// Masaüstünde alt sayfaların sol gezinme rayı korunarak açılmasını sağlar.
class ShellPageOpener extends InheritedWidget {
  const ShellPageOpener({super.key, required this.open, required super.child});

  /// Sayfayı kabuğun içinde açar. Masaüstünde ray korunur, mobilde normal route kullanılır.
  final void Function(Widget page) open;

  static ShellPageOpener? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellPageOpener>();

  @override
  bool updateShouldNotify(ShellPageOpener oldWidget) => open != oldWidget.open;
}
