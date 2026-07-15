import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meal_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(
      envString: '''
ENVIRONMENT=development
API_BASE_URL_ANDROID=http://127.0.0.1:1
API_BASE_URL_IOS=http://127.0.0.1:1
API_BASE_URL_PRODUCTION=http://127.0.0.1:1
''',
    );
  });

  testWidgets('MyApp builds (dotenv + provider tree)', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
