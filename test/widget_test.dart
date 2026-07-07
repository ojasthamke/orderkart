import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orderkart/app.dart';

void main() {
  testWidgets('App renders successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: OrderKartApp(),
      ),
    );
    expect(find.byType(OrderKartApp), findsOneWidget);
  });
}
