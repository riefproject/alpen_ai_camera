import 'package:alpen_ai_camera/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const AlpenAiCameraApp());

    expect(find.text('Camera Workspace'), findsOneWidget);
    expect(find.text('Camera Module Skeleton'), findsOneWidget);
  });
}
