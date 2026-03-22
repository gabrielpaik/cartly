import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wimc/main.dart';

void main() {
  testWidgets('saved tab empty state smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedTabView()));

    expect(find.text('Saved carts'), findsOneWidget);
    expect(find.text('아직 저장된 카트가 없어요'), findsOneWidget);
  });
}
