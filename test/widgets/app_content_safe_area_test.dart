import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app content leaves room for a three-button navigation bar',
      (tester) async {
    const navigationBarHeight = 48.0;
    final contentKey = GlobalKey();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          padding: EdgeInsets.only(bottom: navigationBarHeight),
          viewPadding: EdgeInsets.only(bottom: navigationBarHeight),
        ),
        child: MaterialApp(
          builder: (context, child) => SafeArea(
            bottom: true,
            top: false,
            child: child ?? const SizedBox.shrink(),
          ),
          home: SizedBox.expand(
            key: contentKey,
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );

    final contentBox = tester.renderObject<RenderBox>(
      find.byKey(contentKey),
    );

    expect(contentBox.size, const Size(800, 600 - navigationBarHeight));
    expect(contentBox.localToGlobal(Offset.zero).dy, 0);
  });
}
