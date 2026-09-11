import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Horizontal [PageView] that keeps each tab mounted after its first visit.
class SwipeableTabBody extends StatelessWidget {
  const SwipeableTabBody({
    super.key,
    required this.controller,
    required this.onPageChanged,
    required this.children,
  });

  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      onPageChanged: onPageChanged,
      physics: const _SnappyPagePhysics(parent: BouncingScrollPhysics()),
      children: [
        for (var i = 0; i < children.length; i++)
          KeepAliveTab(
            child: _TabSwipeTransition(
              controller: controller,
              index: i,
              child: children[i],
            ),
          ),
      ],
    );
  }
}

/// Keeps a [PageView] child in the tree after it has been built once.
class KeepAliveTab extends StatefulWidget {
  const KeepAliveTab({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Depth + parallax transform driven by the [PageController] offset.
///
/// Only the [Transform] rebuilds while dragging — [child] is passed through
/// [AnimatedBuilder] so heavy tab screens (Clock, Attendance) stay put.
class _TabSwipeTransition extends StatelessWidget {
  const _TabSwipeTransition({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final page = _pageOffset;
        final delta = (page - index).clamp(-1.0, 1.0);
        final progress = Curves.easeOutCubic.transform(delta.abs());

        final scale = 1.0 - (progress * 0.07);
        final opacity = 1.0 - (progress * 0.16);
        final lift = progress * 18;
        final parallax = delta * 14;
        final tilt = delta * 0.12;

        return Opacity(
          opacity: opacity.clamp(0.55, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0009)
              ..translate(-parallax, lift)
              ..rotateY(tilt)
              ..scale(scale, scale),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  double get _pageOffset {
    if (!controller.hasClients || !controller.position.haveDimensions) {
      return controller.initialPage.toDouble();
    }
    return controller.page ?? controller.initialPage.toDouble();
  }
}

/// Page snapping with a slightly underdamped spring so the tab settles
/// with a short, elastic bounce instead of a linear stop.
class _SnappyPagePhysics extends PageScrollPhysics {
  const _SnappyPagePhysics({super.parent});

  @override
  _SnappyPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _SnappyPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.55,
    stiffness: 85,
    ratio: 0.82,
  );
}

/// Shared tap + swipe tab switching for employee and manager bottom navs.
mixin SwipeableBottomNavMixin<T extends StatefulWidget> on State<T> {
  static const _tabAnimationDuration = Duration(milliseconds: 420);

  late final PageController pageController = PageController();
  int selectedIndex = 0;
  bool _isProgrammaticPageChange = false;
  int _indexBeforeProgrammaticChange = 0;

  /// Immediate side effects (filters, selected icon) when a tab is chosen.
  void onTabSelected(int index, int previousIndex) {}

  /// Runs after the destination page is in the tree (resume / refresh).
  void onTabSettled(int index, int previousIndex) {}

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void selectTab(int index, {bool animate = true}) {
    if (selectedIndex == index) return;
    _indexBeforeProgrammaticChange = selectedIndex;
    onTabSelected(index, selectedIndex);
    setState(() => selectedIndex = index);
    HapticFeedback.selectionClick();

    if (!pageController.hasClients) {
      onTabSettled(index, _indexBeforeProgrammaticChange);
      return;
    }

    _isProgrammaticPageChange = true;
    final movement = animate
        ? pageController.animateToPage(
            index,
            duration: _tabAnimationDuration,
            curve: const Cubic(0.16, 0.84, 0.18, 1.0),
          )
        : Future<void>.sync(() => pageController.jumpToPage(index));

    movement.whenComplete(() {
      if (mounted) _isProgrammaticPageChange = false;
    });
  }

  void onSwipePageChanged(int index) {
    if (_isProgrammaticPageChange) {
      if (index == selectedIndex) {
        onTabSettled(index, _indexBeforeProgrammaticChange);
      }
      return;
    }
    if (selectedIndex == index) return;
    final previousIndex = selectedIndex;
    onTabSelected(index, previousIndex);
    setState(() => selectedIndex = index);
    HapticFeedback.selectionClick();
    onTabSettled(index, previousIndex);
  }
}
