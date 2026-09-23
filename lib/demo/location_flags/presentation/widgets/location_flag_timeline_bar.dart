import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_timeline.dart';

class LocationFlagTimelineBar extends StatefulWidget {
  const LocationFlagTimelineBar({
    super.key,
    required this.window,
    required this.segments,
    required this.progress,
    this.intervals = const [],
    this.paintUnrecorded = false,
    this.height = 14,
  });

  final PolicyDayWindow window;
  final List<LocationTimelineSegment> segments;
  final double progress;
  final List<LocationOutsideInterval> intervals;
  final bool paintUnrecorded;
  final double height;

  @override
  State<LocationFlagTimelineBar> createState() =>
      _LocationFlagTimelineBarState();
}

class _LocationFlagTimelineBarState extends State<LocationFlagTimelineBar> {
  static const _labelStyle = TextStyle(
    fontSize: 11,
    color: kGreyColor,
    fontWeight: FontWeight.w500,
  );
  static const _minZoom = 1.0;
  static const _maxZoom = 8.0;

  double? _tipX;
  DateTime? _tipAt;
  double _zoom = 1.0;
  double _pan = 0.0; // 0..1 left-edge fraction of scrollable range
  double _zoomAtGestureStart = 1.0;

  PolicyDayWindow get dayWindow => widget.window;

  PolicyDayWindow get viewWindow {
    final totalMs = dayWindow.duration.inMilliseconds;
    if (totalMs <= 0 || _zoom <= 1.0) return dayWindow;
    final visibleMs = (totalMs / _zoom).round().clamp(1, totalMs);
    final maxOffsetMs = totalMs - visibleMs;
    final offsetMs = (maxOffsetMs * _pan.clamp(0.0, 1.0)).round();
    final start = dayWindow.start.add(Duration(milliseconds: offsetMs));
    final end = start.add(Duration(milliseconds: visibleMs));
    return PolicyDayWindow(start: start, end: end);
  }

  double get viewProgress {
    final view = viewWindow;
    final totalMs = dayWindow.duration.inMilliseconds;
    if (totalMs <= 0) return 0;
    final absolute = dayWindow.start.add(
      Duration(
        milliseconds: (totalMs * widget.progress.clamp(0.0, 1.0)).round(),
      ),
    );
    final viewMs = view.duration.inMilliseconds;
    if (viewMs <= 0) return 0;
    if (!absolute.isAfter(view.start)) return 0;
    if (!absolute.isBefore(view.end)) return 1;
    return absolute.difference(view.start).inMilliseconds / viewMs;
  }

  void _showTip(double dx, double width) {
    if (width <= 0) return;
    final view = viewWindow;
    final totalMs = view.duration.inMilliseconds;
    if (totalMs <= 0) return;
    final x = dx.clamp(0.0, width);
    final t = (x / width).clamp(0.0, 1.0);
    final at = view.start.add(
      Duration(milliseconds: (totalMs * t).round()),
    );
    setState(() {
      _tipX = x;
      _tipAt = at;
    });
  }

  void _toggleTip(double dx, double width) {
    if (_tipX != null || _tipAt != null) {
      setState(() {
        _tipX = null;
        _tipAt = null;
      });
      return;
    }
    _showTip(dx, width);
  }

  void _setZoom(double next, {double? focalFraction}) {
    final clamped = next.clamp(_minZoom, _maxZoom);
    if (clamped == _zoom) return;

    final oldView = viewWindow;
    final focal = (focalFraction ?? 0.5).clamp(0.0, 1.0);
    final focalTime = oldView.start.add(
      Duration(
        milliseconds: (oldView.duration.inMilliseconds * focal).round(),
      ),
    );

    _zoom = clamped;
    if (_zoom <= 1.0) {
      _pan = 0;
      return;
    }

    final totalMs = dayWindow.duration.inMilliseconds;
    final visibleMs = (totalMs / _zoom).round().clamp(1, totalMs);
    final maxOffsetMs = (totalMs - visibleMs).clamp(0, totalMs);
    if (maxOffsetMs <= 0) {
      _pan = 0;
      return;
    }

    final desiredStartMs =
        focalTime.difference(dayWindow.start).inMilliseconds -
        (visibleMs * focal).round();
    _pan = (desiredStartMs / maxOffsetMs).clamp(0.0, 1.0);
  }

  String _statusAt(DateTime at) {
    final totalMs = dayWindow.duration.inMilliseconds;
    final filledUntil = dayWindow.start.add(
      Duration(
        milliseconds: (totalMs * widget.progress.clamp(0.0, 1.0)).round(),
      ),
    );
    if (at.isAfter(filledUntil)) return 'Upcoming';

    for (final segment in widget.segments) {
      final inSegment =
          !at.isBefore(segment.start) && !at.isAfter(segment.end);
      if (inSegment) {
        switch (segment.kind) {
          case LocationTimelineKind.inside:
            return 'Inside';
          case LocationTimelineKind.outside:
            return 'Outside';
          case LocationTimelineKind.onBreak:
            return 'Break';
          case LocationTimelineKind.unknown:
            return 'Missing';
        }
      }
    }
    if (widget.paintUnrecorded) return 'Missing';
    return 'Upcoming';
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'Inside':
        return kPrimaryColor;
      case 'Outside':
        return kredColor;
      case 'Missing':
        return kOrangeColor;
      case 'Break':
        return const Color(0xFFF3C900);
      default:
        return kGreyColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final view = viewWindow;
        final placed = _layoutMarks(width, view);
        final above = placed.where((m) => m.above).toList();
        final below = placed.where((m) => !m.above).toList();
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _EagerScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_EagerScaleGestureRecognizer>(
              _EagerScaleGestureRecognizer.new,
              (_EagerScaleGestureRecognizer instance) {
                instance
                  ..onStart = (details) {
                    _zoomAtGestureStart = _zoom;
                  }
                  ..onUpdate = (details) {
                    _onScaleUpdate(details, width);
                  };
              },
            ),
          },
          child: Column(
              children: [
                SizedBox(
                  height: 16,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final mark in above)
                        Positioned(
                          left: mark.left,
                          top: 0,
                          child: Text(mark.text, style: _labelStyle),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: widget.height + 20,
                  width: double.infinity,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _toggleTip(details.localPosition.dx, width),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          height: widget.height,
                          child: CustomPaint(
                            painter: _TimelinePainter(
                              window: view,
                              segments: widget.segments,
                              progress: viewProgress.clamp(0.0, 1.0),
                              paintUnrecorded: widget.paintUnrecorded,
                            ),
                          ),
                        ),
                        if (_tipX != null && _tipAt != null)
                          _TipBubble(
                            x: _tipX!,
                            width: width,
                            status: _statusAt(_tipAt!),
                            time: LocationFlagEvaluator.formatClock(
                              _tipAt!,
                              showPeriod: false,
                            ),
                            color: _colorForStatus(_statusAt(_tipAt!)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 16,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final mark in below)
                        Positioned(
                          left: mark.left,
                          top: 0,
                          child: Text(mark.text, style: _labelStyle),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _LegendDot(color: kPrimaryColor, label: 'Inside'),
                    _LegendDot(color: kredColor, label: 'Outside'),
                    _LegendDot(color: kOrangeColor, label: 'Missing'),
                    _LegendDot(color: Color(0xFFF3C900), label: 'Break'),
                  ],
                ),
              ],
            ),
        );
      },
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double width) {
    // Two-finger pinch zoom.
    if (details.pointerCount >= 2) {
      final focal = width <= 0
          ? 0.5
          : (details.localFocalPoint.dx / width).clamp(0.0, 1.0);
      setState(() {
        _tipX = null;
        _tipAt = null;
        _setZoom(
          _zoomAtGestureStart * details.scale,
          focalFraction: focal,
        );
      });
      return;
    }

    // One finger: pan when zoomed, otherwise scrub the tip.
    if (_zoom > 1.0) {
      final totalMs = dayWindow.duration.inMilliseconds;
      final visibleMs = totalMs / _zoom;
      final maxOffsetMs = totalMs - visibleMs;
      if (maxOffsetMs > 0 && width > 0) {
        final deltaFraction =
            (-details.focalPointDelta.dx / width) * (visibleMs / totalMs);
        final panRange = maxOffsetMs / totalMs;
        setState(() {
          _pan = (_pan + deltaFraction / panRange).clamp(0.0, 1.0);
          _tipX = null;
          _tipAt = null;
        });
      }
      return;
    }

    _showTip(details.localFocalPoint.dx, width);
  }

  List<_AxisLabel> _layoutMarks(double width, PolicyDayWindow view) {
    final totalMs = view.duration.inMilliseconds;
    if (width <= 0 || totalMs <= 0) return const [];

    final marks = LocationFlagTimeline.axisMarks(
      window: view,
      intervals: widget.intervals,
    )..sort((a, b) => a.at.compareTo(b.at));

    final aboveOccupied = <Rect>[];
    final belowOccupied = <Rect>[];
    final out = <_AxisLabel>[];

    for (final mark in marks) {
      final isEdge =
          mark.kind == LocationTimelineMarkKind.start ||
          mark.kind == LocationTimelineMarkKind.end;
      final text = LocationFlagEvaluator.formatClock(
        mark.at,
        compact: true,
        // Keep am/pm on the day edges; interior leave/return times stay plain.
        showPeriod: isEdge,
      );
      final painter = TextPainter(
        text: TextSpan(text: text, style: _labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final elapsed = mark.at.difference(view.start).inMilliseconds;
      final t = (elapsed / totalMs).clamp(0.0, 1.0);
      var left = (t * width) - (painter.width / 2);
      if (mark.kind == LocationTimelineMarkKind.start) {
        left = 0;
      } else if (mark.kind == LocationTimelineMarkKind.end) {
        left = width - painter.width;
      }
      left = left.clamp(0.0, (width - painter.width).clamp(0.0, width));
      final rect = Rect.fromLTWH(left, 0, painter.width, painter.height);

      final overlapsAbove = aboveOccupied.any(
        (existing) => existing.inflate(8).overlaps(rect),
      );
      final overlapsBelow = belowOccupied.any(
        (existing) => existing.inflate(8).overlaps(rect),
      );

      final above = !overlapsAbove || overlapsBelow;
      if (above) {
        aboveOccupied.add(rect);
      } else {
        belowOccupied.add(rect);
      }
      out.add(_AxisLabel(text: text, left: left, above: above));
    }
    return out;
  }
}

class _AxisLabel {
  const _AxisLabel({
    required this.text,
    required this.left,
    required this.above,
  });

  final String text;
  final double left;
  final bool above;
}

/// Wins against parent scroll when the user pinches with two fingers.
class _EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

class _TipBubble extends StatelessWidget {
  const _TipBubble({
    required this.x,
    required this.width,
    required this.status,
    required this.time,
    required this.color,
  });

  final double x;
  final double width;
  final String status;
  final String time;
  final Color color;

  static const _bubbleWidth = 206.0;

  @override
  Widget build(BuildContext context) {
    final maxLeft = (width - _bubbleWidth).clamp(0.0, width);
    final left = (x - _bubbleWidth / 2).clamp(0.0, maxLeft);
    final tailX = (x - left).clamp(10.0, _bubbleWidth - 10.0);
    final onYellow = status == 'Break';
    return Positioned(
      left: left,
      top: -46,
      width: _bubbleWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _bubbleWidth,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$status  $time',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onYellow ? kBlack : kWhite,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(_bubbleWidth, 7),
            painter: _BubbleTailPainter(color: color, x: tailX),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.x});

  final Color color;
  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(x - 6, 0)
      ..lineTo(x, size.height)
      ..lineTo(x + 6, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.x != x;
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.window,
    required this.segments,
    required this.progress,
    required this.paintUnrecorded,
  });

  final PolicyDayWindow window;
  final List<LocationTimelineSegment> segments;
  final double progress;
  final bool paintUnrecorded;

  static const Color track = Color(0xFFE9E9E9);
  static const Color inside = kPrimaryColor;
  static const Color outside = kredColor;
  static const Color onBreak = Color(0xFFF3C900);
  static const Color unrecorded = kOrangeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final trackRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      radius,
    );
    canvas.drawRRect(trackRect, Paint()..color = track);

    final totalMs = window.duration.inMilliseconds;
    if (totalMs <= 0 || progress <= 0) return;

    canvas.save();
    canvas.clipRRect(trackRect);

    final revealWidth = size.width * progress;
    canvas.clipRect(Rect.fromLTWH(0, 0, revealWidth, size.height));

    if (paintUnrecorded) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = unrecorded,
      );
    }

    for (final segment in segments) {
      final color = _colorFor(segment.kind);
      if (color == null) continue;
      final start = _x(segment.start, size.width, totalMs);
      final end = _x(segment.end, size.width, totalMs);
      if (end <= start) continue;
      final rect = Rect.fromLTRB(start, 0, end, size.height);
      canvas.drawRect(rect, Paint()..color = color);
    }

    canvas.restore();
  }

  double _x(DateTime at, double width, int totalMs) {
    final elapsed = at.difference(window.start).inMilliseconds;
    return (elapsed / totalMs).clamp(0.0, 1.0) * width;
  }

  Color? _colorFor(LocationTimelineKind kind) {
    switch (kind) {
      case LocationTimelineKind.inside:
        return inside;
      case LocationTimelineKind.outside:
        return outside;
      case LocationTimelineKind.onBreak:
        return onBreak;
      case LocationTimelineKind.unknown:
        return unrecorded;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.segments != segments ||
        oldDelegate.paintUnrecorded != paintUnrecorded ||
        oldDelegate.window.start != window.start ||
        oldDelegate.window.end != window.end;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: kGreyColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
