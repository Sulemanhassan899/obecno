import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Particle Tether / OrbConverge — Flutter port of the Originkit React component.
///
/// Fibonacci-sphere particles that converge and spin in perspective.
class OrbConverge extends StatefulWidget {
  const OrbConverge({
    super.key,
    this.width,
    this.height,
    this.dotColor = const Color(0xFF94FD00),
    this.density = 300,
    this.dotSize = 153,
    this.speed = 50,
    this.spinTurns = 0,
    this.spread = 180,
    this.turn = 32,
    this.tilt = -1,
    this.drag = 0,
    this.damping = 10,
  });

  final double? width;
  final double? height;
  final Color dotColor;

  /// Originkit density 20–300. Higher = more dots.
  final double density;

  /// Originkit dotSize 20–300.
  final double dotSize;

  /// Originkit speed -100–100.
  final double speed;

  /// Whole spins per converge cycle (-3…3).
  final int spinTurns;

  /// Ball spread 40–180.
  final double spread;

  /// Rest yaw in degrees (-180…180).
  final double turn;

  /// Rest pitch in degrees (-90…90).
  final double tilt;

  /// Pointer drag sensitivity 0–300. 0 disables interaction.
  final double drag;

  /// Velocity damping 1–100.
  final double damping;

  @override
  State<OrbConverge> createState() => _OrbConvergeState();
}

class _OrbConvergeState extends State<OrbConverge>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _phase = 0;
  double _yaw = 0;
  double _pitch = 0;
  double _vx = 0;
  double _vy = 0;
  bool _dragging = false;
  Offset? _lastPointer;
  int _lastPointerMs = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    if (last == Duration.zero) {
      setState(() {});
      return;
    }
    final dt = math.min(0.05, (elapsed - last).inMicroseconds / 1e6);
    final speed = _clamp(widget.speed, -100, 100) / 50;
    var phase = (_phase + (dt * speed) / _OrbMath.period) % 1.0;
    if (phase < 0) phase += 1;

    if (!_dragging) {
      final damping = _clamp(widget.damping, 1, 100);
      final decay = math.exp(-damping * 0.12 * dt);
      _yaw += _vx * dt;
      _pitch += _vy * dt;
      _vx *= decay;
      _vy *= decay;
    }

    final restPitch = (_clamp(widget.tilt, -90, 90) * math.pi) / 180;
    _pitch = _clamp(
      _pitch,
      -math.pi / 2 - restPitch,
      math.pi / 2 - restPitch,
    );

    setState(() => _phase = phase);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (widget.drag <= 0) return;
    _dragging = true;
    _lastPointer = e.position;
    _lastPointerMs = e.timeStamp.inMilliseconds;
    _vx = 0;
    _vy = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_dragging || _lastPointer == null) return;
    final size = context.size?.width ?? 120;
    final k = ((_clamp(widget.drag, 0, 300) / 100) * _OrbMath.tau) /
        math.max(1, size);
    final dx = (e.position.dx - _lastPointer!.dx) * k;
    final dy = (e.position.dy - _lastPointer!.dy) * k;
    final now = e.timeStamp.inMilliseconds;
    final span = math.max(1, now - _lastPointerMs);
    _lastPointer = e.position;
    _lastPointerMs = now;
    _yaw -= dx;
    _pitch += dy;
    _vx = (-dx / span) * 1000;
    _vy = (dy / span) * 1000;
  }

  void _onPointerUp(PointerEvent e) {
    _dragging = false;
    _lastPointer = null;
  }

  @override
  Widget build(BuildContext context) {
    Widget canvas = CustomPaint(
      painter: _OrbConvergePainter(
        phase: _phase,
        dragYaw: _yaw,
        dragPitch: _pitch,
        dotColor: widget.dotColor,
        density: widget.density,
        dotSize: widget.dotSize,
        spinTurns: widget.spinTurns,
        spread: widget.spread,
        turn: widget.turn,
        tilt: widget.tilt,
      ),
      child: const SizedBox.expand(),
    );

    if (widget.drag > 0) {
      canvas = Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: canvas,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRect(child: canvas),
    );
  }
}

class _OrbConvergePainter extends CustomPainter {
  _OrbConvergePainter({
    required this.phase,
    required this.dragYaw,
    required this.dragPitch,
    required this.dotColor,
    required this.density,
    required this.dotSize,
    required this.spinTurns,
    required this.spread,
    required this.turn,
    required this.tilt,
  });

  final double phase;
  final double dragYaw;
  final double dragPitch;
  final Color dotColor;
  final double density;
  final double dotSize;
  final int spinTurns;
  final double spread;
  final double turn;
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width;
    final ch = size.height;
    if (cw < 2 || ch < 2) return;

    final ballSize = math.max(4.0, math.min(cw, ch));
    final bx = (cw - ballSize) / 2;
    final by = (ch - ballSize) / 2;

    final params = _OrbParams(
      n: _clamp(density, 20, 300) / 100,
      sp: _clamp(spread, 40, 180) / 100,
      ds: _OrbMath.dotScaleFor(ballSize) * (_clamp(dotSize, 20, 300) / 100),
      yw: (_clamp(turn, -180, 180) * math.pi) / 180 + dragYaw,
      sn: spinTurns.clamp(-3, 3).toDouble(),
      pc: (_clamp(tilt, -90, 90) * math.pi) / 180 + dragPitch,
      t: phase,
      dot: dotColor,
    );

    final fit = _OrbMath.autoFit(
      ballSize,
      params,
      (_clamp(turn, -180, 180) * math.pi) / 180,
      (_clamp(tilt, -90, 90) * math.pi) / 180,
    );
    final half = ballSize / 2;
    final dots = <_Dot>[];
    _OrbMath.frame(phase, params, dots);

    var drawn = 0;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    _OrbMath.project(dots, ballSize, params, (x, y, r, a, col) {
      if (drawn >= _OrbMath.maxDots) return;
      final rr = r * (0.55 + 0.45 * fit);
      if (rr <= 0.05 || a <= 0.004) return;

      var dr = rr;
      var da = math.min(1.0, a);
      if (dr < _OrbMath.minRadius) {
        da *= (dr / _OrbMath.minRadius) * (dr / _OrbMath.minRadius);
        dr = _OrbMath.minRadius;
      }

      final cx = bx + half + (x - half) * fit;
      final cy = by + half + (y - half) * fit;
      paint.color = col.withOpacity(da);
      canvas.drawCircle(Offset(cx, cy), dr, paint);
      drawn += 1;
    });
  }

  @override
  bool shouldRepaint(covariant _OrbConvergePainter old) {
    return old.phase != phase ||
        old.dragYaw != dragYaw ||
        old.dragPitch != dragPitch ||
        old.dotColor != dotColor ||
        old.density != density ||
        old.dotSize != dotSize ||
        old.spinTurns != spinTurns ||
        old.spread != spread ||
        old.turn != turn ||
        old.tilt != tilt;
  }
}

// ─── Math (faithful port of Originkit Particle Tether) ───────────────────────

class _OrbParams {
  const _OrbParams({
    required this.n,
    required this.sp,
    required this.ds,
    required this.yw,
    required this.sn,
    required this.pc,
    required this.t,
    required this.dot,
  });

  final double n;
  final double sp;
  final double ds;
  final double yw;
  final double sn;
  final double pc;
  final double t;
  final Color dot;
}

class _Dot {
  const _Dot(
    this.x,
    this.y,
    this.z, [
    this.rScale = 1,
    this.aScale = 1,
    this.color,
  ]);

  final double x;
  final double y;
  final double z;
  final double rScale;
  final double aScale;
  final Color? color;
}

typedef _Emit = void Function(
  double x,
  double y,
  double r,
  double a,
  Color col,
);

abstract final class _OrbMath {
  static const double tau = math.pi * 2;
  static const double period = 4.8;
  static const double baseSpread = 0.3;
  static const double perspective = 3.5;
  static const double depthSize = 1;
  static const double depthFade = 1;
  static const double minRadius = 0.6;
  static const int maxDots = 1024;

  static final Map<String, double> _fitCache = {};

  static int dotsN(double base, double n) {
    final v = (base * n).round();
    return v < 1 ? 1 : v;
  }

  static double bump(double x) => 0.5 - 0.5 * math.cos(tau * _clamp01(x));

  static List<double> fib(int i, int n) {
    final y = 1 - (i / math.max(1, n - 1)) * 2;
    final r = math.sqrt(math.max(0.0, 1 - y * y));
    final th = 2.399963 * i;
    return [math.cos(th) * r, y, math.sin(th) * r];
  }

  static List<double> polar(List<double> p) {
    return [
      math.acos(_clamp(p[1], -1, 1)),
      math.atan2(p[2], p[0]),
    ];
  }

  static _Dot spin(_Dot p, double yaw, double pitch) {
    final ca = math.cos(yaw);
    final sa = math.sin(yaw);
    final rx = p.x * ca - p.z * sa;
    var rz = p.x * sa + p.z * ca;
    final co = math.cos(pitch);
    final so = math.sin(pitch);
    final ry = p.y * co - rz * so;
    rz = p.y * so + rz * co;
    return _Dot(rx, ry, rz, p.rScale, p.aScale, p.color);
  }

  static void frame(double t, _OrbParams p, List<_Dot> out) {
    final n = dotsN(150, p.n);
    final k = bump(t);
    for (var i = 0; i < n; i += 1) {
      final pol = polar(fib(i, n));
      final th = pol[0] + (math.pi / 2 - pol[0]) * k;
      final sr = math.sin(th);
      out.add(
        spin(
          _Dot(
            math.cos(pol[1]) * sr,
            math.cos(th),
            math.sin(pol[1]) * sr,
            0.8 + 0.5 * k,
            0.9,
          ),
          tau * t,
          0.4,
        ),
      );
    }
  }

  static void project(
    List<_Dot> pts,
    double size,
    _OrbParams p,
    _Emit emit,
  ) {
    final c = size / 2;
    final R = size * baseSpread * p.sp;
    final pv = perspective;
    final yaw = p.yw + tau * p.sn * p.t;

    final list = <List<Object>>[];
    for (final pt in pts) {
      final q = spin(pt, yaw, p.pc);
      final z = q.z;
      final s = pv / (pv - z);
      final f = _clamp01((z + 1.1) / 2.2);
      list.add([
        c + q.x * R * s,
        c + q.y * R * s,
        p.ds * (0.4 + 1.6 * depthSize * f) * s * q.rScale,
        (0.07 + 0.93 * math.pow(f, 1.55 * depthFade)) * q.aScale,
        q.color ?? p.dot,
        z,
      ]);
    }
    list.sort((a, b) => (a[5] as double).compareTo(b[5] as double));
    for (final d in list) {
      emit(
        d[0] as double,
        d[1] as double,
        d[2] as double,
        d[3] as double,
        d[4] as Color,
      );
    }
  }

  static double autoFit(
    double size,
    _OrbParams p,
    double restYaw,
    double restPitch,
  ) {
    final key = '$size/${p.n}/${p.sp}/$restYaw/$restPitch/${p.sn}';
    final hit = _fitCache[key];
    if (hit != null) return hit;

    final half = size / 2;
    var ext = 0.0;

    void emit(double x, double y, double r, double a, Color col) {
      if (a <= 0.05 || r <= 0.15) return;
      ext = math.max(
        ext,
        math.max(
          (x - half).abs() + 0.5 * r,
          (y - half).abs() + 0.5 * r,
        ),
      );
    }

    for (var k = 0; k < 20; k += 1) {
      final t = k / 20.0;
      final probe = _OrbParams(
        n: p.n,
        sp: p.sp,
        ds: 1,
        yw: restYaw,
        sn: p.sn,
        pc: restPitch,
        t: t,
        dot: const Color(0xFFFFFFFF),
      );
      final out = <_Dot>[];
      frame(t, probe, out);
      project(out, size, probe, emit);
    }

    final fit = ext > 1
        ? math.max(0.55, math.min(1.7, (0.415 * size) / ext))
        : 1.0;
    _fitCache[key] = fit;
    return fit;
  }

  static double dotScaleFor(double size) {
    if (size <= 46) return 0.4;
    if (size <= 190) return 0.4 + ((size - 46) / 144) * 0.6;
    if (size <= 340) return 1 + ((size - 190) / 150) * 0.55;
    return 1.55;
  }
}

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double _clamp(num v, num lo, num hi) {
  if (v < lo) return lo.toDouble();
  if (v > hi) return hi.toDouble();
  return v.toDouble();
}
