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
}
