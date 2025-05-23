import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/main.dart';
import '../';
import 'package:busbuddyapp/lib/pages/Admin pages/Admin_Log_In.dart';
import 'package:busbuddyapp/lib/pages/Admin pages/Notification pages/Admin_Notifications.dart';

void main() {
  group('BusBuddyApp Widget Tests', () {
    testWidgets('Parent Login Screen loads correctly',
        (WidgetTester tester) async {
      // Build the Parent Login Screen and trigger a frame.
      await tester.pumpWidget(MaterialApp(home: ParentLogInScreen()));

      // Verify that the Phone Number and Password fields are present.
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify that the Submit button is present.
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('Admin Login Screen loads correctly',
        (WidgetTester tester) async {
      // Build the Admin Login Screen and trigger a frame.
      await tester.pumpWidget(MaterialApp(home: AdminLogInScreen()));

      // Verify that the Phone Number and Password fields are present.
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify that the Submit button is present.
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('Admin Notifications Page loads correctly',
        (WidgetTester tester) async {
      // Build the Admin Notifications Page and trigger a frame.
      await tester.pumpWidget(MaterialApp(home: AdminNotifications()));

      // Verify that the "My Notifications" text is present.
      expect(find.text('My Notifications'), findsOneWidget);

      // Verify that the Clear button is present.
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('Navigation between pages works', (WidgetTester tester) async {
      // Build the main app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that the initial screen is the Parent Login Screen.
      expect(find.byType(ParentLogInScreen), findsOneWidget);

      // Simulate navigation to the Admin Login Screen.
      await tester.tap(
          find.byIcon(Icons.person)); // Assuming this navigates to Admin Login.
      await tester.pumpAndSettle();

      // Verify that the Admin Login Screen is displayed.
      expect(find.byType(AdminLogInScreen), findsOneWidget);
    });
  });
}
