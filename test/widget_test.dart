import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maid/ui/screens/voice_assistant_screen.dart';
import 'package:maid/providers/app_provider.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('VoiceAssistantScreen renders correctly with Stop Voice controls', (WidgetTester tester) async {
    final appProvider = AppProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appProvider,
        child: const MaterialApp(
          home: VoiceAssistantScreen(),
        ),
      ),
    );

    expect(find.text('Maid Voice Assistant'), findsOneWidget);
    expect(find.text('Stop Audio'), findsOneWidget);
  });
}
