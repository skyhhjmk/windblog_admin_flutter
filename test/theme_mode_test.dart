import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windblog_admin_flutter/main.dart';
import 'package:windblog_admin_flutter/utils/app_theme_controller.dart';
import 'package:windblog_admin_flutter/utils/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.instance.load();
  });

  group('AdminTheme', () {
    test('build() produces light theme by default', () {
      final theme = AdminTheme.build();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
      expect(theme.cardTheme.color, Colors.white);
      expect(theme.appBarTheme.backgroundColor, Colors.white);
      expect(
        theme.navigationRailTheme.backgroundColor,
        AdminTheme.navigationColor,
      );
    });

    test(
      'build(brightness: Brightness.dark) and AdminTheme.dark() produce dark theme',
      () {
        final darkTheme = AdminTheme.dark();
        expect(darkTheme.brightness, Brightness.dark);
        expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF0F172A));
        expect(darkTheme.cardTheme.color, const Color(0xFF1E293B));
        expect(darkTheme.appBarTheme.backgroundColor, const Color(0xFF1E293B));
        expect(
          darkTheme.navigationRailTheme.backgroundColor,
          const Color(0xFF0B101D),
        );
      },
    );

    test('AdminTheme.light() produces light theme', () {
      final lightTheme = AdminTheme.light();
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
      expect(lightTheme.cardTheme.color, Colors.white);
    });
  });

  group('StorageService ThemeMode', () {
    test('defaults to ThemeMode.system when no preference is saved', () async {
      SharedPreferences.setMockInitialValues({});
      final mode = await StorageService.getThemeMode();
      expect(mode, ThemeMode.system);
    });

    test('persists and restores light and dark theme modes', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.saveThemeMode(ThemeMode.dark);
      expect(await StorageService.getThemeMode(), ThemeMode.dark);

      await StorageService.saveThemeMode(ThemeMode.light);
      expect(await StorageService.getThemeMode(), ThemeMode.light);

      await StorageService.saveThemeMode(ThemeMode.system);
      expect(await StorageService.getThemeMode(), ThemeMode.system);
    });
  });

  group('AppThemeController', () {
    test('updates mode and notifies listeners', () async {
      final controller = AppThemeController.instance;
      int notifications = 0;
      void listener() => notifications++;
      controller.addListener(listener);

      try {
        await controller.setThemeMode(ThemeMode.dark);
        expect(controller.themeMode, ThemeMode.dark);
        expect(notifications, 1);

        // Setting same mode shouldn't notify again
        await controller.setThemeMode(ThemeMode.dark);
        expect(notifications, 1);

        await controller.setThemeMode(ThemeMode.light);
        expect(controller.themeMode, ThemeMode.light);
        expect(notifications, 2);
      } finally {
        controller.removeListener(listener);
      }
    });
  });

  group('ThemeModePopupButton Widget', () {
    testWidgets('renders popup button and switches theme on selection', (
      tester,
    ) async {
      await AppThemeController.instance.setThemeMode(ThemeMode.system);

      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.light(),
          darkTheme: AdminTheme.dark(),
          themeMode: AppThemeController.instance.themeMode,
          home: const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: ThemeModePopupButton(),
            ),
          ),
        ),
      );

      expect(find.byType(ThemeModePopupButton), findsOneWidget);
      expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);

      // Tap the popup button to open menu
      await tester.tap(find.byType(ThemeModePopupButton));
      await tester.pumpAndSettle();

      // Find the dark mode option
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.dark_mode_outlined));
      await tester.pumpAndSettle();

      expect(AppThemeController.instance.themeMode, ThemeMode.dark);
    });
  });
}
