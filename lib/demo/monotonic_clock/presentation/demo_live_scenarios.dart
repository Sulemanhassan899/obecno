class DemoLiveScenario {
  const DemoLiveScenario({
    required this.number,
    required this.title,
    required this.situation,
    required this.steps,
    required this.expected,
  });

  final int number;
  final String title;
  final String situation;
  final List<String> steps;
  final String expected;
}

const liveDemoScenarios = <DemoLiveScenario>[
  DemoLiveScenario(
    number: 1,
    title: 'Normal Check In',
    situation: 'Log in at 9:00 AM and check in a few minutes later.',
    steps: [
      'Stay on real device time.',
      'Open this demo after login (login timestamp is captured).',
      'Wait until ~09:05 AM.',
      'Press CHECK IN.',
    ],
    expected:
        'Phone 09:05 · Calculated 09:05 · Clock Changed NO · MATCH · Send 09:05 AM',
  ),
  DemoLiveScenario(
    number: 2,
    title: 'Forgot check-in, then change phone time',
    situation:
        'Login 09:00. Close the app. At 1:00 PM change the phone clock to 9:00 AM, open the app, check in.',
    steps: [
      'Capture login at 09:00 (stay logged in).',
      'Press CLOSE APP (or leave the app).',
      'Wait until real 1:00 PM, or tap ACTUAL +4 HOURS.',
      'Tap PHONE → 09:00 AM (or change emulator Settings).',
      'Press APP OPEN (or reopen the app).',
      'Press CHECK IN.',
    ],
    expected:
        'Phone 09:00 · Actual/Calculated 01:00 PM · Clock Changed YES · MATCH · Send 01:00 PM — never 09:00 AM',
  ),
  DemoLiveScenario(
    number: 3,
    title: 'Clock already wrong at check-in',
    situation:
        'Phone shows 9:00 AM while real time is 1:00 PM. Check in. Never send 09:00 AM.',
    steps: [
      'Login earlier while the clock was correct.',
      'Change phone time to 9:00 AM at real 1:00 PM.',
      'Press CHECK IN.',
    ],
    expected:
        'Phone 09:00 · Calculated 01:00 PM · Clock Changed YES · Send 01:00 PM. Phone time is never authoritative.',
  ),
  DemoLiveScenario(
    number: 4,
    title: 'Change phone time before Break In',
    situation: 'Checked in at 9:00 AM. At 1:00 PM change phone to 12:00 PM, then Break In.',
    steps: [
      'CHECK IN at 09:00 (honest).',
      'At real 1:00 PM set phone to 12:00 PM.',
      'Press BREAK IN.',
    ],
    expected: 'Phone 12:00 PM · Calculated 01:00 PM · YES · MATCH · Break In = 01:00 PM',
  ),
  DemoLiveScenario(
    number: 5,
    title: 'Change phone time before Break Out',
    situation: 'Break in at 1:00 PM. At 1:30 PM set phone to 1:00 PM, then Break Out.',
    steps: [
      'BREAK IN at real 01:00 PM.',
      'At real 01:30 PM set phone to 01:00 PM.',
      'Press BREAK OUT.',
    ],
    expected: 'Phone 01:00 PM · Calculated 01:30 PM · YES · MATCH · Break Out = 01:30 PM',
  ),
  DemoLiveScenario(
    number: 6,
    title: 'Change phone time before Check Out',
    situation: 'Work until 6:00 PM. Set phone to 5:00 PM, then Check Out.',
    steps: [
      'At real 06:00 PM set phone to 05:00 PM.',
      'Press CHECK OUT.',
    ],
    expected: 'Phone 05:00 PM · Calculated 06:00 PM · YES · MATCH · Check Out = 06:00 PM',
  ),
  DemoLiveScenario(
    number: 7,
    title: 'Offline Check In with changed phone time',
    situation: 'Offline at real 1:00 PM. Phone set to 9:00 AM. Check in. Sync later.',
    steps: [
      'Press GO OFFLINE.',
      'At real 1:00 PM set phone to 9:00 AM.',
      'Press CHECK IN (saved PENDING).',
      'You may change the phone clock again.',
      'Press GO ONLINE then SYNC NOW.',
    ],
    expected: 'Queued CHECK_IN = 01:00 PM. Sync still sends 01:00 PM.',
  ),
  DemoLiveScenario(
    number: 8,
    title: 'Offline Break In',
    situation: 'Offline. Real 1:00 PM. Phone 12:00 PM. Break In.',
    steps: [
      'GO OFFLINE.',
      'Set phone to 12:00 PM at real 1:00 PM.',
      'Press BREAK IN, then sync when online.',
    ],
    expected: 'BREAK_IN = 01:00 PM (not 12:00 PM)',
  ),
  DemoLiveScenario(
    number: 9,
    title: 'Offline Break Out',
    situation: 'Break started 1:00 PM. At 1:30 PM phone says 1:00 PM. Offline Break Out.',
    steps: [
      'GO OFFLINE.',
      'At real 01:30 PM set phone to 01:00 PM.',
      'Press BREAK OUT, then sync.',
    ],
    expected: 'BREAK_OUT = 01:30 PM',
  ),
  DemoLiveScenario(
    number: 10,
    title: 'Offline Check Out',
    situation: 'Real 6:00 PM. Phone 5:00 PM. Offline Check Out.',
    steps: [
      'GO OFFLINE.',
      'At real 06:00 PM set phone to 05:00 PM.',
      'Press CHECK OUT, then sync.',
    ],
    expected: 'CHECK_OUT = 06:00 PM (PENDING → sync still 06:00 PM)',
  ),
  DemoLiveScenario(
    number: 11,
    title: 'All four events in one day',
    situation: 'Full day with mixed honest and manipulated phone times.',
    steps: [
      'CHECK IN at 09:00 (phone honest).',
      'BREAK IN at 01:00 PM (phone 12:00 PM).',
      'BREAK OUT at 01:30 PM (phone 01:00 PM).',
      'CHECK OUT at 06:00 PM (phone 05:00 PM).',
    ],
    expected:
        'CHECK_IN 09:00 AM · BREAK_IN 01:00 PM · BREAK_OUT 01:30 PM · CHECK_OUT 06:00 PM',
  ),
];
