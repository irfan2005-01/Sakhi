import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Sakhi dashboard loads title', (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    expect(find.text('Sakhi'), findsOneWidget);
  });
}
