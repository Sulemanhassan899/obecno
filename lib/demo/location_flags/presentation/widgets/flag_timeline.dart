import 'package:flutter/material.dart';
import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';

const kInside = Color(0xFF22C55E);
const kOutside = Color(0xFFEF4444);
const kMissing = Color(0xFFF97316);
const kBreak = Color(0xFFF5C518);
const kFuture = Color(0xFFE6E6E6);
const kCheckedOut = Color(0xFF2F6FED);

Color colorForKind(SlotKind kind) {
  switch (kind) {
    case SlotKind.inside:
      return kInside;
    case SlotKind.outside:
      return kOutside;
    case SlotKind.missing:
      return kMissing;
    case SlotKind.onBreak:
      return kBreak;
    case SlotKind.notReached:
      return kFuture;
  }
}

class TimelineSlot {
  const TimelineSlot({
    required this.time,
    required this.kind,
    this.record,
    this.marker,
  });

  final DateTime time;
  final SlotKind kind;
  final LocationFlagRecord? record;
  final String? marker;
}

class FlagTimeline extends StatefulWidget {
  const FlagTimeline({
    super.key,
    required this.slots,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final List<TimelineSlot> slots;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<FlagTimeline> createState() => _FlagTimelineState();
}

class _FlagTimelineState extends State<FlagTimeline> {
  double _scale = 1;
  double _pan = 0;
  int? _selected;
  double _lastScale = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 168,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                onScaleStart: (details) => _lastScale = _scale,
                onScaleUpdate: (details) {
                  setState(() {
                    if (details.pointerCount >= 2) {
                      _scale = (_lastScale * details.scale).clamp(1.0, 8.0);
                      if (_scale == 1) _pan = 0;
                    } else if (_scale > 1) {
                      _pan += details.focalPointDelta.dx;
                      final maxPan = width * (_scale - 1);
                      _pan = _pan.clamp(-maxPan, 0);
                    }
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Transform.translate(
                        offset: Offset(_pan, 0),
                        child: Transform.scale(
                          alignment: Alignment.centerLeft,
                          scaleX: _scale,
                          scaleY: 1,
                          child: CustomPaint(
                            size: Size(width, 168),
                            painter: _TimelinePainter(
                              slots: widget.slots,
                              rangeStart: widget.rangeStart,
                              rangeEnd: widget.rangeEnd,
                            ),
                          ),
                        ),
                      ),
                      ..._hitTargets(width),
                      if (_selected != null) _bubble(width),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendDot(color: kInside, label: 'Inside'),
            _LegendDot(color: kOutside, label: 'Outside'),
            _LegendDot(color: kMissing, label: 'Missing'),
            _LegendDot(color: kBreak, label: 'Break'),
          ],
        ),
      ],
    );
  }

  List<Widget> _hitTargets(double width) {
    if (widget.slots.isEmpty) return const [];
    final span = widget.rangeEnd.difference(widget.rangeStart).inMinutes;
    if (span <= 0) return const [];
    return [
      for (var i = 0; i < widget.slots.length; i++)
        Positioned(
          left: _x(widget.slots[i].time, width, span),
          top: 36,
          width: mathMax(8, (width * _scale) / widget.slots.length),
          height: 28,
          child: Semantics(
            button: true,
            label: _semantics(widget.slots[i]),
            child: GestureDetector(
              onTap: () => setState(() => _selected = _selected == i ? null : i),
              behavior: HitTestBehavior.translucent,
            ),
          ),
        ),
    ];
  }

  Widget _bubble(double width) {
    final slot = widget.slots[_selected!];
    final span = widget.rangeEnd.difference(widget.rangeStart).inMinutes;
    final left = (_x(slot.time, width, span)).clamp(8.0, width - 180);
    return Positioned(
      left: left,
      top: 4,
      child: _Bubble(slot: slot),
    );
  }

  double _x(DateTime time, double width, int span) {
    final minutes = time.difference(widget.rangeStart).inMinutes;
    final raw = (minutes / span) * width * _scale + _pan;
    return raw;
  }

  String _semantics(TimelineSlot slot) {
    final record = slot.record;
    final status = switch (slot.kind) {
      SlotKind.inside => 'inside',
      SlotKind.outside => 'outside',
      SlotKind.missing => 'missing',
      SlotKind.onBreak => 'break',
      SlotKind.notReached => 'not reached',
    };
    return '${_clock(slot.time)}, flag ${record?.flagNumber ?? '-'}, $status, '
        'office ${record?.matchedLocationName ?? 'none'}, '
        'distance ${record?.distanceMeters?.toStringAsFixed(0) ?? '-'} meters, '
        'accuracy ${record?.accuracyMeters?.toStringAsFixed(0) ?? '-'} meters, '
        'break ${record?.breakStatus == true}';
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.slots,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final List<TimelineSlot> slots;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final span = rangeEnd.difference(rangeStart).inMinutes;
    if (span <= 0) return;
    const barTop = 78.0;
    const barHeight = 16.0;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, size.width, barHeight),
      const Radius.circular(20),
    );
    canvas.save();
    canvas.clipRRect(bar);
    canvas.drawRRect(bar, Paint()..color = kFuture);
    for (final slot in slots) {
      final start = slot.time.difference(rangeStart).inMinutes / span;
      final end = slot.time
              .add(const Duration(minutes: kFlagIntervalMinutes))
              .difference(rangeStart)
              .inMinutes /
          span;
      final rect = Rect.fromLTRB(
        start * size.width,
        barTop,
        end * size.width,
        barTop + barHeight,
      );
      canvas.drawRect(rect, Paint()..color = colorForKind(slot.kind));
    }
    canvas.restore();

    final labels = _lanes(size, span);
    for (final item in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: const TextStyle(color: Color(0xFF111111), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (item.x - painter.width / 2).clamp(0.0, size.width - painter.width).toDouble();
      final dy = item.above
          ? 78.0 - 18 - (item.lane * 16) - painter.height
          : 78.0 + 22 + (item.lane * 16);
      painter.paint(canvas, Offset(dx, dy));
    }
  }

  List<_Label> _lanes(Size size, int span) {
    final marks = <_Label>[];
    void add(DateTime time, String text) {
      final x = time.difference(rangeStart).inMinutes / span * size.width;
      marks.add(_Label(x, text, true, 0));
    }

    if (slots.isEmpty) return marks;
    add(rangeStart, _clock(rangeStart));
    add(rangeEnd, _clock(rangeEnd));
    for (final slot in slots) {
      if (slot.marker != null) add(slot.time, slot.marker!);
    }

    const gap = 52.0;
    final placed = <_Label>[];
    for (final mark in marks) {
      var lane = 0;
      var above = true;
      while (placed.any((other) => other.above == above && other.lane == lane && (other.x - mark.x).abs() < gap)) {
        if (above) {
          above = false;
        } else {
          above = true;
          lane += 1;
        }
        if (lane > 3) break;
      }
      placed.add(_Label(mark.x, mark.text, above, lane));
    }
    return placed;
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) => true;
}

class _Label {
  const _Label(this.x, this.text, this.above, this.lane);
  final double x;
  final String text;
  final bool above;
  final int lane;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.slot});
  final TimelineSlot slot;

  @override
  Widget build(BuildContext context) {
    final record = slot.record;
    final status = switch (slot.kind) {
      SlotKind.inside => 'INSIDE',
      SlotKind.outside => 'OUTSIDE',
      SlotKind.missing => 'MISSING',
      SlotKind.onBreak => 'BREAK',
      SlotKind.notReached => 'NOT REACHED',
    };
    return Material(
      color: const Color(0xFF222222),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_clock(slot.time), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Flag ${record?.flagNumber ?? '—'}'),
              Text('Status: $status'),
              Text('Office: ${record?.matchedLocationName ?? '—'}'),
              Text('Distance: ${record?.distanceMeters == null ? '—' : '${record!.distanceMeters!.toStringAsFixed(0)} m'}'),
              Text('Accuracy: ${record?.accuracyMeters == null ? '—' : '${record!.accuracyMeters!.toStringAsFixed(0)} m'}'),
            ],
          ),
        ),
      ),
    );
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ],
    );
  }
}

String _clock(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'pm' : 'am';
  return '$hour:$minute $suffix';
}

double mathMax(double a, double b) => a > b ? a : b;
