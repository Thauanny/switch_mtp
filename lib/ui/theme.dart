import 'package:flutter/material.dart';

/// Vermelho do Switch, usado só como destaque (botão principal, seleção, progresso).
const switchRed = Color(0xFFE60012);

/// Tema moderno e neutro, no estilo dos apps do macOS: superfícies claras (ou escuras),
/// cantos arredondados, bordas finas e o vermelho só onde chama a ação.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: switchRed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      ).copyWith(
        primary: dark ? const Color(0xFFFF4D5A) : switchRed,
        onPrimary: Colors.white,
        surface: dark ? const Color(0xFF1C1C1F) : const Color(0xFFFFFFFF),
        surfaceContainerLowest: dark
            ? const Color(0xFF161618)
            : const Color(0xFFFFFFFF),
        surfaceContainerLow: dark
            ? const Color(0xFF232326)
            : const Color(0xFFF6F6F7),
        surfaceContainer: dark
            ? const Color(0xFF29292D)
            : const Color(0xFFF0F0F2),
        surfaceContainerHigh: dark
            ? const Color(0xFF303035)
            : const Color(0xFFE9E9EC),
        outlineVariant: dark
            ? const Color(0xFF3A3A40)
            : const Color(0xFFE2E2E6),
      );
  final radius = BorderRadius.circular(8);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.compact,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 420,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

/// Ícone e cor por tipo de arquivo (jogos do Switch em vermelho, imagens em azul...).
(IconData, Color) fileVisual(String name, {required bool isFolder}) {
  if (isFolder) return (Icons.folder_rounded, const Color(0xFF4A9EFF));
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'nsp' ||
    'nsz' ||
    'xci' ||
    'xcz' => (Icons.sports_esports_rounded, switchRed),
    'nro' || 'ovl' => (Icons.apps_rounded, const Color(0xFF8E59FF)),
    'png' ||
    'jpg' ||
    'jpeg' ||
    'bmp' ||
    'webp' ||
    'gif' => (Icons.image_rounded, const Color(0xFF2EA8E6)),
    'mp4' ||
    'mkv' ||
    'webm' ||
    'mov' => (Icons.movie_rounded, const Color(0xFFF08A24)),
    'mp3' ||
    'wav' ||
    'ogg' ||
    'flac' => (Icons.music_note_rounded, const Color(0xFFE5489B)),
    'zip' ||
    '7z' ||
    'rar' ||
    'tar' ||
    'gz' => (Icons.inventory_2_rounded, const Color(0xFF9C7A4E)),
    'ini' ||
    'txt' ||
    'json' ||
    'cfg' ||
    'log' ||
    'xml' => (Icons.description_rounded, const Color(0xFF7C8592)),
    'bin' || 'dat' => (Icons.memory_rounded, const Color(0xFF5E9E6E)),
    _ => (Icons.insert_drive_file_rounded, const Color(0xFF8B929C)),
  };
}

/// Nome do tipo para a coluna "Tipo" e as dicas.
String fileKind(String name, {required bool isFolder}) {
  if (isFolder) return 'Pasta';
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'nsp' || 'nsz' => 'Jogo (NSP)',
    'xci' || 'xcz' => 'Jogo (XCI)',
    'nro' => 'Homebrew',
    '' => 'Arquivo',
    _ => ext.toUpperCase(),
  };
}
