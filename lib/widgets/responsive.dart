import 'package:flutter/material.dart';

/// Utilitaires de mise en page responsive (évite les débordements).
class Responsive {
  Responsive._();

  static const double _tablet = 640;
  static const double _desktop = 1024;

  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < _tablet;
  }

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= _tablet && w < _desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= _desktop;
  }

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 780;

  /// Nombre de colonnes plein-écran pour les grilles, garantit des tuiles ≥ `minTile` px.
  static int gridColumns(BuildContext context, {double minTile = 230, int max = 6}) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = (w / minTile).floor();
    return cols.clamp(1, max).toInt();
  }

  /// Taille horizontale maximale du contenu (lecture confortable sur grand écran).
  static BoxConstraints pageConstraints(BuildContext context, {double maxWidth = 1100}) {
    return BoxConstraints(maxWidth: maxWidth);
  }

  /// Espace de page standard.
  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= _desktop) return const EdgeInsets.all(28);
    if (w >= _tablet) return const EdgeInsets.all(20);
    return const EdgeInsets.all(14);
  }
}