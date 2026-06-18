import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:les_theme_app/main.dart';

void main() {
  testWidgets('shows setup screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LesThemeApp());
    await tester.pump();

    expect(find.text('Event Display'), findsOneWidget);
    expect(find.text('Display App Setup'), findsOneWidget);
  });
}
