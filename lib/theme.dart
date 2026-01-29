import 'package:flutter/material.dart';

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

/// Standard component sizing used across the app.
class AppSizes {
  static const double minTapTarget = 44;
  static const double navBarHeight = 72;
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

/// Hub Frete color palette - Logistics green theme
/// Uses green (#00885B) as primary color for logistics branding
class LightModeColors {
  // Primary: Hub Frete green
  static const lightPrimary = Color(0xFF00885B);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFB3E5D4);
  static const lightOnPrimaryContainer = Color(0xFF002919);

  // Secondary: Complementary gray-blue
  static const lightSecondary = Color(0xFF5C6B7A);
  static const lightOnSecondary = Color(0xFFFFFFFF);

  // Tertiary: Subtle accent color
  static const lightTertiary = Color(0xFF6B7C8C);
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Error colors
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);

  // Surface and background: High contrast for readability
  static const lightSurface = Color(0xFFFBFCFD);
  static const lightOnSurface = Color(0xFF1A1C1E);
  static const lightBackground = Color(0xFFF7F9FA);
  static const lightSurfaceVariant = Color(0xFFE2E8F0);
  static const lightOnSurfaceVariant = Color(0xFF44474E);

  // Home/header surfaces (Fretebras/Airbnb-inspired)
  static const lightHeader = Color(0xFF141414);
  static const lightOnHeader = Color(0xFFFFFFFF);
  static const lightHeaderMuted = Color(0xFFB9BCC2);

  // Outline and shadow
  static const lightOutline = Color(0xFF74777F);
  static const lightShadow = Color(0xFF000000);
  static const lightInversePrimary = Color(0xFFACC7E3);

  // Neutrals for minimal UI
  static const lightSurface2 = Color(0xFFF2F5F7);
  static const lightSurface3 = Color(0xFFE9EEF2);
}

/// Dark mode colors with good contrast
class DarkModeColors {
  // Primary: Lighter green for dark background
  static const darkPrimary = Color(0xFF66C9A6);
  static const darkOnPrimary = Color(0xFF002919);
  static const darkPrimaryContainer = Color(0xFF005640);
  static const darkOnPrimaryContainer = Color(0xFFB3E5D4);

  // Secondary
  static const darkSecondary = Color(0xFFBCC7D6);
  static const darkOnSecondary = Color(0xFF2E3842);

  // Tertiary
  static const darkTertiary = Color(0xFFB8C8D8);
  static const darkOnTertiary = Color(0xFF344451);

  // Error colors
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);

  // Surface and background: True dark mode
  static const darkSurface = Color(0xFF1A1C1E);
  static const darkOnSurface = Color(0xFFE2E8F0);
  static const darkSurfaceVariant = Color(0xFF44474E);
  static const darkOnSurfaceVariant = Color(0xFFC4C7CF);

  // Home/header surfaces (Fretebras/Airbnb-inspired)
  static const darkHeader = Color(0xFF141414);
  static const darkOnHeader = Color(0xFFFFFFFF);
  static const darkHeaderMuted = Color(0xFFB9BCC2);

  // Outline and shadow
  static const darkOutline = Color(0xFF8E9099);
  static const darkShadow = Color(0xFF000000);
  static const darkInversePrimary = Color(0xFF00885B);

  // Neutrals for minimal UI
  static const darkSurface2 = Color(0xFF202327);
  static const darkSurface3 = Color(0xFF2A2E33);
}

/// Status badge colors for delivery tracking
class StatusColors {
  static const waiting = Color(0xFFFFA726); // Orange/Yellow
  static const collected = Color(0xFF42A5F5); // Blue
  static const inTransit = Color(0xFF66BB6A); // Green
  static const delivered = Color(0xFF00885B); // Hub Frete Green
  static const problem = Color(0xFFEF5350); // Red
  static const cancelled = Color(0xFF9E9E9E); // Gray
}

/// Chat-specific colors to match the conversation UI design.
///
/// Keep these colors centralized to avoid hardcoding in widgets.
class ChatColors {
  // Light mode
  // Minimal / neutral base (avoid strong green cast)
  static const lightChatBackground = Color(0xFFF6F7F9);
  static const lightIncomingBubble = Color(0xFFFFFFFF);
  // Slight tint to keep brand feel without “gritar” verde
  static const lightOutgoingBubble = Color(0xFFF1F7F4);
  static const lightDatePill = Color(0xFFEEF2F5);

  // Dark mode
  static const darkChatBackground = Color(0xFF0F2A29);
  static const darkIncomingBubble = Color(0xFF1D2426);
  static const darkOutgoingBubble = Color(0xFF1E3B2A);
  static const darkDatePill = Color(0xFF1B2F2E);
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme with modern, neutral aesthetic
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    shadow: LightModeColors.lightShadow,
    inversePrimary: LightModeColors.lightInversePrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  splashFactory: NoSplash.splashFactory,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: LightModeColors.lightSurface,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.14), width: 1),
    ),
  ),
  dividerTheme: DividerThemeData(color: LightModeColors.lightOutline.withValues(alpha: 0.12), thickness: 1, space: 1),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
    minVerticalPadding: 0,
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: AppSizes.navBarHeight,
    elevation: 0,
    backgroundColor: LightModeColors.lightSurface,
    indicatorColor: Colors.transparent,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final isSelected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 26,
        color: isSelected ? LightModeColors.lightPrimary : LightModeColors.lightOnSurfaceVariant.withValues(alpha: 0.75),
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final isSelected = states.contains(WidgetState.selected);
      return TextStyle(
        fontWeight: FontWeight.w600,
        color: isSelected ? LightModeColors.lightPrimary : LightModeColors.lightOnSurfaceVariant.withValues(alpha: 0.75),
      );
    }),
  ),
  chipTheme: ChipThemeData(
    side: BorderSide.none,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
    labelStyle: _buildTextTheme(Brightness.light).labelMedium,
    backgroundColor: LightModeColors.lightSurface3,
    selectedColor: LightModeColors.lightPrimaryContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.lightSurface2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.18)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: LightModeColors.lightPrimary, width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: LightModeColors.lightError),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(AppSizes.minTapTarget, AppSizes.minTapTarget)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
      textStyle: WidgetStatePropertyAll(_buildTextTheme(Brightness.light).labelLarge?.copyWith(fontWeight: FontWeight.w700)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(AppSizes.minTapTarget, AppSizes.minTapTarget)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
      side: WidgetStatePropertyAll(BorderSide(color: LightModeColors.lightOutline.withValues(alpha: 0.22))),
      textStyle: WidgetStatePropertyAll(_buildTextTheme(Brightness.light).labelLarge?.copyWith(fontWeight: FontWeight.w700)),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.light),
);

/// Dark theme with good contrast and readability
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    shadow: DarkModeColors.darkShadow,
    inversePrimary: DarkModeColors.darkInversePrimary,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkSurface,
  splashFactory: NoSplash.splashFactory,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: DarkModeColors.darkSurface2,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.16), width: 1),
    ),
  ),
  dividerTheme: DividerThemeData(color: DarkModeColors.darkOutline.withValues(alpha: 0.16), thickness: 1, space: 1),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
    minVerticalPadding: 0,
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: AppSizes.navBarHeight,
    elevation: 0,
    backgroundColor: DarkModeColors.darkSurface2,
    indicatorColor: Colors.transparent,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final isSelected = states.contains(WidgetState.selected);
      return IconThemeData(
        size: 26,
        color: isSelected ? DarkModeColors.darkPrimary : DarkModeColors.darkOnSurfaceVariant.withValues(alpha: 0.72),
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final isSelected = states.contains(WidgetState.selected);
      return TextStyle(
        fontWeight: FontWeight.w600,
        color: isSelected ? DarkModeColors.darkPrimary : DarkModeColors.darkOnSurfaceVariant.withValues(alpha: 0.72),
      );
    }),
  ),
  chipTheme: ChipThemeData(
    side: BorderSide.none,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
    labelStyle: _buildTextTheme(Brightness.dark).labelMedium,
    backgroundColor: DarkModeColors.darkSurface3,
    selectedColor: DarkModeColors.darkPrimaryContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.darkSurface3,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.22)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.22)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: DarkModeColors.darkPrimary, width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: DarkModeColors.darkError),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(AppSizes.minTapTarget, AppSizes.minTapTarget)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
      textStyle: WidgetStatePropertyAll(_buildTextTheme(Brightness.dark).labelLarge?.copyWith(fontWeight: FontWeight.w700)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(AppSizes.minTapTarget, AppSizes.minTapTarget)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
      side: WidgetStatePropertyAll(BorderSide(color: DarkModeColors.darkOutline.withValues(alpha: 0.26))),
      textStyle: WidgetStatePropertyAll(_buildTextTheme(Brightness.dark).labelLarge?.copyWith(fontWeight: FontWeight.w700)),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

/// Build text theme using system fonts
TextTheme _buildTextTheme(Brightness brightness) {
  return TextTheme(
    displayLarge: const TextStyle(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    displayMedium: const TextStyle(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: const TextStyle(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: const TextStyle(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: const TextStyle(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: const TextStyle(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: const TextStyle(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: const TextStyle(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: const TextStyle(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: const TextStyle(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: const TextStyle(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: const TextStyle(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    bodyLarge: const TextStyle(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: const TextStyle(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: const TextStyle(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
  );
}
