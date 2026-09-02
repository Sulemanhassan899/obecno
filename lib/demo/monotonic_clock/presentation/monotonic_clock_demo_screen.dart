import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/demo/monotonic_clock/domain/demo_time_models.dart';
import 'package:obecno/demo/monotonic_clock/presentation/demo_live_scenarios.dart';
import 'package:obecno/demo/monotonic_clock/presentation/demo_time_format.dart';
import 'package:obecno/demo/monotonic_clock/presentation/monotonic_clock_demo_controller.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';

class MonotonicClockDemoScreen extends StatefulWidget {
  const MonotonicClockDemoScreen({super.key});

  static const routePath = '/demo/monotonic-clock';

  @override
  State<MonotonicClockDemoScreen> createState() =>
      _MonotonicClockDemoScreenState();
}

class _MonotonicClockDemoScreenState extends State<MonotonicClockDemoScreen> {
  late final MonotonicClockDemoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MonotonicClockDemoController();
    _controller.addListener(_onUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.init(auth: context.read<AuthProvider>());
    });
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.ready) {
      return const Scaffold(
        backgroundColor: kbackground1,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final snap = _controller.snapshot;
    final employee = _controller.employee;

    return Scaffold(
      backgroundColor: kbackground1,
      appBar: AppBar(
        title: const Text('MONOTONIC TIME DEMO'),
        actions: [
          TextButton(
            onPressed: _controller.resetEvents,
            child: const Text('RESET EVENTS'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _EmployeeCard(
            loggedIn: _controller.isEmployeeLoggedIn,
            name: employee?.name,
            email: employee?.email,
            role: employee?.role,
          ),
          const SizedBox(height: 12),
          _ClockModeBar(controller: _controller),
          const SizedBox(height: 12),
          _FlowCard(
            snapshot: snap,
            lastEvent: _controller.lastEvent,
            pendingCount: _controller.pendingSync.length,
          ),
          if (snap.rebootDetected) ...[
            const SizedBox(height: 12),
            const _Banner(
              color: kRed50,
              text:
                  'REBOOT DETECTED. Monotonic clock reset. Attendance timestamps are refused until a new login.',
            ),
          ],
          if (snap.clockChange.changed && !snap.rebootDetected) ...[
            const SizedBox(height: 12),
            _Banner(
              color: const Color(0xFFFFF4CC),
              text:
                  'PHONE TIME ≠ CALCULATED TIME. Difference ${DemoTimeFormat.clockDifference(snap.clockChange.difference)}. Phone time will not be sent.',
            ),
          ],
          if (_controller.statusMessage != null) ...[
            const SizedBox(height: 12),
            _Banner(color: kPrimaryColor2, text: _controller.statusMessage!),
          ],
          const SizedBox(height: 16),
          _SessionButtons(controller: _controller),
          const SizedBox(height: 16),
          _AttendanceTimesCard(controller: _controller, snapshot: snap),
          const SizedBox(height: 12),
          _ActionButtons(controller: _controller),
          const SizedBox(height: 16),
          _TimeControls(controller: _controller),
          const SizedBox(height: 16),
          _HistoryCard(events: _controller.history),
          const SizedBox(height: 12),
          _SyncCard(controller: _controller),
          const SizedBox(height: 16),
          const _CoreRuleCard(),
          const SizedBox(height: 12),
          const _ScenarioGuide(),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.loggedIn,
    this.name,
    this.email,
    this.role,
  });

  final bool loggedIn;
  final String? name;
  final String? email;
  final String? role;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('EMPLOYEE SESSION'),
          const SizedBox(height: 8),
          if (!loggedIn)
            const Text(
              'No employee is logged in. Log in to the app first. This demo uses that session — it does not create a fake login.',
              style: _muted,
            )
          else ...[
            _kv('Name', name ?? '--'),
            _kv('Email', email ?? '--'),
            _kv('Role', role ?? '--'),
            const SizedBox(height: 6),
            const Text(
              'Login timestamp is captured from this employee session and kept across app open/close.',
              style: _muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _ClockModeBar extends StatelessWidget {
  const _ClockModeBar({required this.controller});

  final MonotonicClockDemoController controller;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('CLOCK SOURCE'),
          const SizedBox(height: 8),
          SegmentedButton<DemoClockMode>(
            segments: const [
              ButtonSegment(
                value: DemoClockMode.live,
                label: Text('LIVE DEVICE'),
              ),
              ButtonSegment(
                value: DemoClockMode.simulated,
                label: Text('SIMULATED'),
              ),
            ],
            selected: {controller.mode},
            onSelectionChanged: (value) {
              controller.setMode(value.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            controller.isSimulated
                ? 'Fake clocks starting at 09:00 AM. CHANGE TIME jumps this demo clock.'
                : 'Real device clocks, plus CHANGE TIME offsets for this demo only (emulator Settings are not required).',
            style: _muted,
          ),
        ],
      ),
    );
  }
}

class _TimeControls extends StatelessWidget {
  const _TimeControls({required this.controller});

  final MonotonicClockDemoController controller;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('CHANGE TIME'),
          const SizedBox(height: 4),
          const Text(
            'Actual time moves monotonic + wall together. Phone time moves the wall clock only.',
            style: _muted,
          ),
          const SizedBox(height: 8),
          const Text('ACTUAL TIME', style: _labelStyle),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _Btn(
                label: 'ACTUAL +30 MIN',
                compact: true,
                onTap: () =>
                    controller.advanceActual(const Duration(minutes: 30)),
              ),
              _Btn(
                label: 'ACTUAL +1 HOUR',
                compact: true,
                onTap: () => controller.advanceActual(const Duration(hours: 1)),
              ),
              _Btn(
                label: 'ACTUAL +4 HOURS',
                compact: true,
                onTap: () => controller.advanceActual(const Duration(hours: 4)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('PHONE TIME ONLY', style: _labelStyle),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _Btn(
                label: 'PHONE −3h',
                compact: true,
                onTap: () =>
                    controller.shiftPhoneWallClock(const Duration(hours: -3)),
              ),
              _Btn(
                label: 'PHONE −1h',
                compact: true,
                onTap: () =>
                    controller.shiftPhoneWallClock(const Duration(hours: -1)),
              ),
              _Btn(
                label: 'PHONE +1h',
                compact: true,
                onTap: () =>
                    controller.shiftPhoneWallClock(const Duration(hours: 1)),
              ),
              _Btn(
                label: 'PHONE +2h',
                compact: true,
                onTap: () =>
                    controller.shiftPhoneWallClock(const Duration(hours: 2)),
              ),
              _Btn(
                label: 'PHONE → 09:00 AM',
                compact: true,
                onTap: () => controller.setPhoneTo(hour: 9),
              ),
              _Btn(
                label: 'PHONE → 12:00 PM',
                compact: true,
                onTap: () => controller.setPhoneTo(hour: 12),
              ),
              _Btn(
                label: 'PHONE → 01:00 PM',
                compact: true,
                onTap: () => controller.setPhoneTo(hour: 13),
              ),
              _Btn(
                label: 'PHONE → 05:00 PM',
                compact: true,
                onTap: () => controller.setPhoneTo(hour: 17),
              ),
              _Btn(
                label: 'PHONE → 07:00 AM',
                compact: true,
                onTap: () => controller.setPhoneTo(hour: 7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('REBOOT', style: _labelStyle),
          const SizedBox(height: 4),
          _Btn(
            label: 'SIMULATE REBOOT',
            compact: true,
            onTap: controller.simulateReboot,
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.snapshot,
    required this.lastEvent,
    required this.pendingCount,
  });

  final TrustedTimeSnapshot snapshot;
  final TrustedAttendanceEvent? lastEvent;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final login = snapshot.loginAnchor;
    final open = snapshot.latestAppOpen;
    final close = snapshot.latestAppClose;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('TIME FLOW'),
          const SizedBox(height: 4),
          const Text(
            'Phone Time → Monotonic Clock → Login Time → Calculated Actual Time → Compare → Event Time → Server',
            style: _muted,
          ),
          const Divider(height: 24),
          _kv(
            'Current Phone Time',
            DemoTimeFormat.time(snapshot.phoneWallClock),
          ),
          _kv(
            'Phone Monotonic Time',
            DemoTimeFormat.monotonic(snapshot.currentMonotonic),
          ),
          const SizedBox(height: 8),
          _kv('Login Timestamp', DemoTimeFormat.time(login?.wallClockLocal)),
          _kv('Login Date', DemoTimeFormat.date(login?.wallClockLocal)),
          _kv('Login UTC', DemoTimeFormat.utc(login?.wallClockLocal)),
          _kv('Timezone', DemoTimeFormat.timezone(login)),
          _kv(
            'Login Monotonic',
            DemoTimeFormat.monotonic(login?.monotonicElapsed),
          ),
          const SizedBox(height: 8),
          _kv('Latest App-Open', DemoTimeFormat.time(open?.wallClockLocal)),
          _kv('App-Open Date', DemoTimeFormat.date(open?.wallClockLocal)),
          _kv('App-Open UTC', DemoTimeFormat.utc(open?.wallClockLocal)),
          _kv('App-Open count', '${snapshot.appOpenCount}'),
          const SizedBox(height: 8),
          _kv('Latest App-Close', DemoTimeFormat.time(close?.wallClockLocal)),
          _kv('App-Close Date', DemoTimeFormat.date(close?.wallClockLocal)),
          _kv('App-Close UTC', DemoTimeFormat.utc(close?.wallClockLocal)),
          _kv('App-Close count', '${snapshot.appCloseCount}'),
          const SizedBox(height: 8),
          _kv(
            'Calculated Actual Time',
            DemoTimeFormat.time(snapshot.calculatedActualTime),
          ),
          _kv(
            'Actual Event Time',
            DemoTimeFormat.time(snapshot.actualEventTime),
          ),
          _kv(
            'Phone Clock Changed',
            snapshot.rebootDetected
                ? '--'
                : DemoTimeFormat.yesNo(snapshot.clockChange.changed),
          ),
          _kv(
            'Clock Difference',
            snapshot.rebootDetected
                ? '--'
                : DemoTimeFormat.clockDifference(
                    snapshot.clockChange.difference,
                  ),
          ),
          _kv('MATCH / MISMATCH', snapshot.comparison?.label ?? '--'),
          _kv(
            'Attendance Event Time',
            DemoTimeFormat.time(
              lastEvent?.authoritativeTime ?? snapshot.actualEventTime,
            ),
          ),
          _kv(
            'Time Sent To Server',
            DemoTimeFormat.time(
              lastEvent?.timeSentToServer ?? snapshot.actualEventTime,
            ),
          ),
          _kv('Network', DemoTimeFormat.network(snapshot.networkOnline)),
          _kv(
            'Sync status',
            lastEvent == null
                ? (pendingCount == 0 ? '--' : 'PENDING')
                : (lastEvent!.synced ? 'SENT' : 'PENDING'),
          ),
          _kv('Session', snapshot.sessionActive ? 'ACTIVE' : 'NONE'),
        ],
      ),
    );
  }
}

class _SessionButtons extends StatelessWidget {
  const _SessionButtons({required this.controller});

  final MonotonicClockDemoController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Btn(label: 'APP OPEN', onTap: controller.recordAppOpen),
        _Btn(label: 'CLOSE APP', onTap: controller.recordAppClose),
        _Btn(
          label: controller.online ? 'GO OFFLINE' : 'GO ONLINE',
          onTap: () => controller.setOnline(!controller.online),
        ),
      ],
    );
  }
}

class _AttendanceTimesCard extends StatelessWidget {
  const _AttendanceTimesCard({
    required this.controller,
    required this.snapshot,
  });

  final MonotonicClockDemoController controller;
  final TrustedTimeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('TODAY'),
          const SizedBox(height: 8),
          _kv('CHECK IN TIME', DemoTimeFormat.time(controller.checkInTime)),
          _kv('BREAK IN TIME', DemoTimeFormat.time(controller.breakInTime)),
          _kv('BREAK OUT TIME', DemoTimeFormat.time(controller.breakOutTime)),
          _kv('CHECK OUT TIME', DemoTimeFormat.time(controller.checkOutTime)),
          const Divider(height: 24),
          _kv(
            'TIME SENT TO SERVER',
            DemoTimeFormat.time(
              controller.lastEvent?.timeSentToServer ??
                  snapshot.calculatedActualTime,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.controller});

  final MonotonicClockDemoController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in DemoAttendanceEventType.values)
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: controller.canPunch
                  ? () => controller.record(type)
                  : null,
              child: Text('[ ${type.label} ]'),
            ),
          ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.events});

  final List<TrustedAttendanceEvent> events;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('EVENT HISTORY'),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No events yet.', style: _muted),
            )
          else
            for (final event in events) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(child: Text(event.type.logName, style: _labelStyle)),
                  _ResultChip(
                    match: event.comparison == TimeComparisonResult.match,
                  ),
                ],
              ),
              _kv('Phone Time', DemoTimeFormat.time(event.phoneWallClock)),
              _kv('Actual Time', DemoTimeFormat.time(event.actualEventTime)),
              _kv(
                'Calculated Time',
                DemoTimeFormat.time(event.calculatedActualTime),
              ),
              _kv('Time Sent', DemoTimeFormat.time(event.timeSentToServer)),
              _kv('Clock Changed', DemoTimeFormat.yesNo(event.clockChanged)),
              _kv('Network', DemoTimeFormat.network(event.networkOnline)),
              _kv('Status', event.synced ? 'SENT' : 'PENDING'),
            ],
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.controller});

  final MonotonicClockDemoController controller;

  @override
  Widget build(BuildContext context) {
    final pending = controller.pendingSync;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('OFFLINE SYNC QUEUE'),
          Text(
            pending.isEmpty
                ? 'Queue empty.'
                : '${pending.length} event(s) waiting. Original timestamps are frozen.',
            style: _muted,
          ),
          for (final event in pending)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${event.type.logName}  ${event.comparison.label}  sent=${DemoTimeFormat.time(event.timeSentToServer)}',
                style: _valueStyle,
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: controller.syncNow,
              child: const Text('SYNC NOW (original timestamps)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreRuleCard extends StatelessWidget {
  const _CoreRuleCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _H('CORE RULE'),
          SizedBox(height: 8),
          Text(
            'User action → capture phone time → get trusted actual time (login + monotonic) → calculate actual time → compare.\n\n'
            'MATCH: use calculated actual time.\n'
            'MISMATCH: use trusted actual time.\n\n'
            'CHECK_IN, BREAK_IN, BREAK_OUT, CHECK_OUT — the phone clock is never the authoritative source.\n\n'
            'Production note: a client monotonic clock only protects time AFTER the login anchor. It cannot prove the original device wall-clock at login was truthful.\n\n'
            'Preferred: Server Trusted Time → Initial Session Time Anchor → Monotonic Clock → Calculated Actual Time → Attendance Event → Local Storage → Offline Queue → Server Validation.\n\n'
            'If login later returns a trusted server timestamp, store that as the login wall clock instead of DateTime.now().',
            style: _muted,
          ),
        ],
      ),
    );
  }
}

class _ScenarioGuide extends StatelessWidget {
  const _ScenarioGuide();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('LIVE TEST SCENARIOS'),
          const SizedBox(height: 4),
          const Text(
            'Instructions only — no auto-load. Use CHANGE TIME below (works in LIVE DEVICE and SIMULATED without emulator Settings). You can also change the emulator clock in LIVE mode.',
            style: _muted,
          ),
          const SizedBox(height: 8),
          for (final scenario in liveDemoScenarios)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: kTransperentColor),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: Text(
                  '${scenario.number}. ${scenario.title}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(scenario.situation, style: _muted),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < scenario.steps.length; i++)
                    _kv('Step ${i + 1}', scenario.steps[i]),
                  const SizedBox(height: 6),
                  Text(
                    'Expect: ${scenario.expected}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.match});

  final bool match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: match ? kgreenColorLight : kRed50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        match ? 'MATCH' : 'MISMATCH',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: match ? kgreenColor : kRed700,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGreyColor6),
      ),
      child: child,
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.Poppins,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        visualDensity: compact
            ? const VisualDensity(horizontal: -4, vertical: -4)
            : VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize:  const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

Widget _kv(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: Text(label, style: _labelStyle)),
        Expanded(flex: 6, child: Text(value, style: _valueStyle)),
      ],
    ),
  );
}

const _labelStyle = TextStyle(
  fontSize: 13,
  color: kGreyColor200,
  fontWeight: FontWeight.w500,
);

const _valueStyle = TextStyle(
  fontSize: 13,
  color: kBlack,
  fontWeight: FontWeight.w600,
);

const _muted = TextStyle(fontSize: 12, color: kGreyColor150, height: 1.4);
