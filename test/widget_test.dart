import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartly/pages/saved_tab_view.dart';

void main() {
  testWidgets('saved tab smoke renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedTabView()));

    expect(find.byType(SavedTabView), findsOneWidget);
  });
}
