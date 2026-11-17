import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slkc_app/core/widgets/empty_state_view.dart';
import 'package:slkc_app/core/widgets/skeleton_loader.dart';

void main() {
  testWidgets('Core UI widgets smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SkeletonBox(width: 80, height: 16),
              EmptyStateView(
                icon: Icons.school,
                title: 'School Attendance',
                message: 'Ready for production',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.text('School Attendance'), findsOneWidget);
    expect(find.text('Ready for production'), findsOneWidget);
  });
}
