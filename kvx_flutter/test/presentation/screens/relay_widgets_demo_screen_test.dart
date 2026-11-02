import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/presentation/screens/relay_widgets_demo_screen.dart';
import 'package:kvx_flutter/presentation/widgets/relay_toggle_switch.dart';

void main() {
  testWidgets(
    'demo renders current widget contracts and updates only local state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: RelayWidgetsDemoScreen()),
      );
      expect(find.text('Relay Widgets Demo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final refresh = find.byTooltip('Làm mới');
      expect(refresh.hitTestable(), findsOneWidget);
      await tester.tap(refresh);
      await tester.pump();
      expect(find.text('Refreshing device...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<RelayToggleSwitch>(find.byType(RelayToggleSwitch)).value,
        isFalse,
      );
      final toggle = find.descendant(
        of: find.byType(RelayToggleSwitch),
        matching: find.byType(Switch),
      );
      await tester.tap(toggle);
      await tester.pump();
      expect(
        tester.widget<RelayToggleSwitch>(find.byType(RelayToggleSwitch)).value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('dropdown selections remain readable in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final colors = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colors, useMaterial3: true),
          home: const RelayWidgetsDemoScreen(),
        ),
      );
      for (final label in ['Giây', 'Phút', 'Hằng ngày']) {
        final text = tester.widget<RichText>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        final foreground = text.text.style!.color!.computeLuminance();
        final background = colors.surface.computeLuminance();
        final lighter = foreground > background ? foreground : background;
        final darker = foreground < background ? foreground : background;
        expect(
          (lighter + 0.05) / (darker + 0.05),
          greaterThanOrEqualTo(4.5),
          reason: '$label must be readable against the form surface',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
