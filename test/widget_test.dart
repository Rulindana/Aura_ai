import 'package:flutter_test/flutter_test.dart';
import 'package:aura_ai/main.dart';

void main() {
  testWidgets('Aura AI loads boot sequence', (WidgetTester tester) async {
    await tester.pumpWidget(const AuraApp());
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('INITIALIZING'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
