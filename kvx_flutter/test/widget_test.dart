import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KvxApp());
    expect(find.text('Devices'), findsOneWidget);
  });
}
