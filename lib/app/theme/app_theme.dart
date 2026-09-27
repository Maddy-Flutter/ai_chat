import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens and semantic color extension for NVIDIA AI Desktop theme.
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.sidebarBg,
    required this.chatBg,
    required this.userBubbleBg,
    required this.assistantBubbleBg,
    required this.codeBlockBg,
    required this.subtleBorder,
    required this.nvidiaGreen,
    required this.textMuted,
  });

  final Color sidebarBg;
  final Color chatBg;
  final Color userBubbleBg;
  final Color assistantBubbleBg;
  final Color codeBlockBg;
  final Color subtleBorder;
  final Color nvidiaGreen;
  final Color textMuted;

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? sidebarBg,
    Color? chatBg,
    Color? userBubbleBg,
    Color? assistantBubbleBg,
    Color? codeBlockBg,
    Color? subtleBorder,
    Color? nvidiaGreen,
    Color? textMuted,
  }) {
    return AppColorsExtension(
      sidebarBg: sidebarBg ?? this.sidebarBg,
      chatBg: chatBg ?? this.chatBg,
      userBubbleBg: userBubbleBg ?? this.userBubbleBg,
      assistantBubbleBg: assistantBubbleBg ?? this.assistantBubbleBg,
      codeBlockBg: codeBlockBg ?? this.codeBlockBg,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      nvidiaGreen: nvidiaGreen ?? this.nvidiaGreen,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      chatBg: Color.lerp(chatBg, other.chatBg, t)!,
      userBubbleBg: Color.lerp(userBubbleBg, other.userBubbleBg, t)!,
      assistantBubbleBg: Color.lerp(assistantBubbleBg, other.assistantBubbleBg, t)!,
      codeBlockBg: Color.lerp(codeBlockBg, other.codeBlockBg, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      nvidiaGreen: Color.lerp(nvidiaGreen, other.nvidiaGreen, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Centralized Material 3 desktop styling tailored for long developer sessions.
class AppTheme {
  AppTheme._();

  // Signature NVIDIA brand accent
  static const Color nvidiaGreen = Color(0xFF76B900);

  // Dark palette tokens
  static const Color darkBaseBg = Color(0xFF0C0E14);
  static const Color darkSidebarBg = Color(0xFF131620);
  static const Color darkSurface = Color(0xFF1B1F2C);
  static const Color darkSurfaceElevated = Color(0xFF24293A);
  static const Color darkBorder = Color(0xFF292E42);
  static const Color darkTextPrimary = Color(0xFFF1F3F9);
  static const Color darkTextMuted = Color(0xFF9199AB);

  // Light palette tokens
  static const Color lightBaseBg = Color(0xFFF8F9FC);
  static const Color lightSidebarBg = Color(0xFFECEFF5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF3F5F9);
  static const Color lightBorder = Color(0xFFDCE1EC);
  static const Color lightTextPrimary = Color(0xFF191D26);
  static const Color lightTextMuted = Color(0xFF6B7485);

  /// Production Dark Theme
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBaseBg,
      primaryColor: nvidiaGreen,
      colorScheme: const ColorScheme.dark(
        primary: nvidiaGreen,
        onPrimary: Colors.black,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        outline: darkBorder,
      ),
      textTheme: textTheme.apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(const Color(0xFF3B425A)),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(6),
      ),
      extensions: const [
        AppColorsExtension(
          sidebarBg: darkSidebarBg,
          chatBg: darkBaseBg,
          userBubbleBg: Color(0xFF232838),
          assistantBubbleBg: Colors.transparent,
          codeBlockBg: Color(0xFF08090E),
          subtleBorder: darkBorder,
          nvidiaGreen: nvidiaGreen,
          textMuted: darkTextMuted,
        ),
      ],
    );
  }

  /// Production Light Theme
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBaseBg,
      primaryColor: nvidiaGreen,
      colorScheme: const ColorScheme.light(
        primary: nvidiaGreen,
        onPrimary: Colors.white,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      textTheme: textTheme.apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(const Color(0xFFB8C0D2)),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(6),
      ),
      extensions: const [
        AppColorsExtension(
          sidebarBg: lightSidebarBg,
          chatBg: lightBaseBg,
          userBubbleBg: Color(0xFFE5E9F2),
          assistantBubbleBg: Colors.transparent,
          codeBlockBg: Color(0xFF1E222D),
          subtleBorder: lightBorder,
          nvidiaGreen: nvidiaGreen,
          textMuted: lightTextMuted,
        ),
      ],
    );
  }
}
