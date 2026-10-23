import 'package:flutter_test/flutter_test.dart';
import 'package:gps/main.dart';

void main() {
  testWidgets('home shows tabs', (tester) async {
    await tester.pumpWidget(const GpsApp(showSplash: false));
    expect(find.text('GPS maps & navigation'), findsOneWidget);
    expect(find.text('Travel tools'), findsOneWidget);
    await tester.tap(find.text('Travel tools'));
    await tester.pump();
    expect(find.text('Compass'), findsOneWidget);
  });
}
