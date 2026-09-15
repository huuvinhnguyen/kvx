import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/presentation/widgets/relay_longlast_form.dart';

void main() {
  group('RelayLonglastForm', () {
    testWidgets('renders all form elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayLonglastForm(
              onActivate: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<DurationUnit>), findsOneWidget);
      expect(find.text('KÍCH HOẠT'), findsOneWidget);
    });

    testWidgets('shows validation error for empty input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayLonglastForm(
              onActivate: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('KÍCH HOẠT'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập thời gian!'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayLonglastForm(
              onActivate: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('KÍCH HOẠT'));
      await tester.pumpAndSettle();

      expect(find.text('Thời gian phải là số nguyên dương!'), findsOneWidget);
    });

    testWidgets('calls onActivate with correct duration in seconds', (tester) async {
      Duration? activatedDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayLonglastForm(
              onActivate: (duration) => activatedDuration = duration,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '30');
      await tester.tap(find.text('KÍCH HOẠT'));
      await tester.pumpAndSettle();

      expect(activatedDuration, const Duration(seconds: 30));
    });

    testWidgets('calls onActivate with correct duration in minutes', (tester) async {
      Duration? activatedDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayLonglastForm(
              onActivate: (duration) => activatedDuration = duration,
            ),
          ),
        ),
      );

      // Change to minutes
      await tester.tap(find.byType(DropdownButtonFormField<DurationUnit>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phút').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('KÍCH HOẠT'));
      await tester.pumpAndSettle();

      expect(activatedDuration, const Duration(minutes: 5));
    });

    testWidgets('clears input after successful submission', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayLonglastForm(
              onActivate: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '10');
      await tester.tap(find.text('KÍCH HOẠT'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
    });

    testWidgets('is disabled when enabled is false', (tester) async {
      Duration? activatedDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayLonglastForm(
              enabled: false,
              onActivate: (duration) => activatedDuration = duration,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '10');
      await tester.tap(find.text('KÍCH HOẠT'));
      await tester.pumpAndSettle();

      expect(activatedDuration, isNull);
    });
  });
}
