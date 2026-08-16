import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:maid/main.dart';
import 'package:maid/providers/app_provider.dart';

void main() {
  testWidgets('MaidApp smoke test with AppProvider', (WidgetTester tester) async {
    final appProvider = AppProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appProvider,
        child: const MaidApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
