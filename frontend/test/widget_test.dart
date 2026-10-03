import 'package:flutter_test/flutter_test.dart';
import 'package:attention_seeker/main.dart';

void main() {
  testWidgets('Attention Seeker app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AttentionSeekerApp());
    expect(find.text('Attention Seeker'), findsWidgets);
    expect(find.text('Find what you lost.'), findsOneWidget);
    expect(find.text('Start Search'), findsOneWidget);
  });
}
