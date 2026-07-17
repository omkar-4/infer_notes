import 'package:flutter/material.dart';

class AppTheme {
  static const Color offWhite = Color(0xFFF7F7F7);
  static const Color offBlack = Color(0xFF1B1D1A);
  static const Color accentColor = Color(0xFFF53A04);
  static const Color primaryTextDark = Color(0xFFF5F5F5);
  static const Color primaryTextLight = Color(0xFF121212);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: offWhite,
      primaryColor: accentColor,
      cardColor: const Color(0xFFEBEBEB),
      dividerColor: Colors.black12,
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        onPrimary: offWhite,
        surface: offWhite,
        onSurface: primaryTextLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: offWhite,
        foregroundColor: primaryTextLight,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextLight, size: 18),
        titleTextStyle: TextStyle(color: primaryTextLight, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(size: 18, color: primaryTextLight),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, color: primaryTextLight),
        bodyLarge: TextStyle(fontSize: 14, color: primaryTextLight),
        titleMedium: TextStyle(fontSize: 13, color: primaryTextLight, fontWeight: FontWeight.w600),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: Color(0xFFFDCBB5), // Solid pastel orange to prevent overlap darkening
        selectionHandleColor: accentColor,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: offBlack,
      primaryColor: accentColor,
      cardColor: offBlack,
      dividerColor: const Color(0xFF383A36),
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        onPrimary: primaryTextDark,
        surface: offBlack,
        onSurface: primaryTextDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: offBlack,
        foregroundColor: primaryTextDark,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextDark, size: 18),
        titleTextStyle: TextStyle(color: primaryTextDark, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(size: 18, color: primaryTextDark),
      listTileTheme: const ListTileThemeData(
        iconColor: primaryTextDark,
        textColor: primaryTextDark,
        selectedColor: accentColor,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF383A36),
        thickness: 1.0,
        space: 1.0,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, color: primaryTextDark),
        bodyLarge: TextStyle(fontSize: 16, color: primaryTextDark),
        titleMedium: TextStyle(fontSize: 13, color: primaryTextDark, fontWeight: FontWeight.w600),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: Color(0xFF6B2508), // Solid dark orange to prevent overlap darkening
        selectionHandleColor: accentColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: primaryTextDark,
        ),
      ),
      useMaterial3: true,
    );
  }
}

/// Standardized IconButton component for the application.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool isSelected;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 18,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 20,
      hoverColor: Colors.white.withValues(alpha: 0.10),
      style: IconButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).dividerColor.withValues(alpha: 0.2) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: isSelected ? BorderSide(color: Theme.of(context).dividerColor, width: 1) : BorderSide.none,
        ),
      ),
    );
  }
}
