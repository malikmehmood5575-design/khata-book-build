// Khata Book — basic smoke test: app khulti hai aur loading nazar aata hai.
import 'package:flutter_test/flutter_test.dart';

import 'package:khatabook/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const KhataBookApp());
    await tester.pump();
    // Pehle frame par shell/loading me se kuch nazar aana chahiye.
    expect(find.text('Khata Book khul raha hai…'), findsOneWidget);
  });
}
