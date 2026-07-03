import 'package:flutter_test/flutter_test.dart';
import 'package:taraqqiyot_mobile/app/taraqqiyot_app.dart';

void main() {
  testWidgets('shows the home dashboard', (tester) async {
    await tester.pumpWidget(const TaraqqiyotApp());

    expect(find.text('Pre-Intermediate'), findsOneWidget);
  });
}
