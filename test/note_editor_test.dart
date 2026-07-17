import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infer_notes/main.dart';

void main() {
  testWidgets('Note Editor has a multiline TextField', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());

    // Expect a TextField to be present
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Verify properties for internal scrolling and full height
    final TextField textField = tester.widget(textFieldFinder);
    expect(textField.maxLines, isNull);
    expect(textField.expands, isTrue);
  });
}
