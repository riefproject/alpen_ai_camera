import 'package:alpen_ai_camera/presentation/widgets/filter_applier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps original preview unchanged for Asli filter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FilterApplier(
            filterName: 'Asli',
            child: Placeholder(),
          ),
        ),
      ),
    );

    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('wraps preview for non-original filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FilterApplier(
            filterName: 'Kristal',
            child: Placeholder(),
          ),
        ),
      ),
    );

    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });
}
