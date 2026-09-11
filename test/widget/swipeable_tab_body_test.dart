import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/widgets/bottom_nav_bars/swipeable_tabs.dart';

void main() {
  testWidgets('swiping the tab body updates the selected index', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _SwipeHarness()));

    expect(find.text('index 0'), findsOneWidget);
    expect(find.text('Tab 0'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('index 1'), findsOneWidget);
    expect(find.text('Tab 1'), findsOneWidget);
    expect(find.text('Tab 0', skipOffstage: false), findsOneWidget);
  });

  testWidgets('tapping a tab jumps without requiring a swipe', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _SwipeHarness()));

    await tester.tap(find.text('Go to 1'));
    await tester.pumpAndSettle();

    expect(find.text('index 1'), findsOneWidget);
    expect(find.text('Tab 1'), findsOneWidget);
  });
}

class _SwipeHarness extends StatefulWidget {
  const _SwipeHarness();

  @override
  State<_SwipeHarness> createState() => _SwipeHarnessState();
}

class _SwipeHarnessState extends State<_SwipeHarness>
    with SwipeableBottomNavMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SwipeableTabBody(
        controller: pageController,
        onPageChanged: onSwipePageChanged,
        children: const [
          Center(child: Text('Tab 0')),
          Center(child: Text('Tab 1')),
        ],
      ),
      bottomNavigationBar: Row(
        children: [
          Text('index $selectedIndex'),
          TextButton(
            onPressed: () => selectTab(1),
            child: const Text('Go to 1'),
          ),
        ],
      ),
    );
  }
}
