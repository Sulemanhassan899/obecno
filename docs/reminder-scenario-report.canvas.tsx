// import {
//   BarChart,
//   Callout,
//   Card,
//   CardBody,
//   CardHeader,
//   Grid,
//   H1,
//   H2,
//   Pill,
//   Row,
//   Stack,
//   Stat,
//   Table,
//   Text,
//   useHostTheme,
// } from "cursor/canvas";

// const FILES = [
//   ["reminder_matrix_scenarios_test.dart", "77", "Full matrix for every reminder"],
//   ["reminder_notification_plan_test.dart", "84", "OS schedule, catch-up, custom clocks"],
//   ["reminder_clock_scenarios_test.dart", "62", "Permission vs picked time"],
//   ["reminder_engine_test.dart", "58", "Timeline logs and attachment"],
//   ["reminder_toggle_settings_test.dart", "27", "One-by-one and combined toggles"],
//   ["reminder_schedule_timezone_test.dart", "2", "Karachi clock stays local"],
// ];

// const MATRIX = [
//   {
//     reminder: "Check In",
//     count: 12,
//     scenarios: [
//       "Disabled is not scheduled",
//       "Before work schedules a future notice",
//       "On the minute delivers immediately",
//       "After the minute does not catch up",
//       "Punch before reminder cancels today",
//       "On-time punch does not log",
//       "Late punch logs at reminder time",
//       "No punch by late morning logs on timeline",
//       "Custom later time schedules that clock",
//       "Rest day is skipped",
//       "Already fired is not delivered again",
//       "Empty user writes nothing",
//     ],
//   },
//   {
//     reminder: "Check In Missed",
//     count: 7,
//     scenarios: [
//       "Disabled is not scheduled",
//       "Before work schedules reminder plus grace",
//       "On the grace minute delivers immediately",
//       "After grace does not catch up",
//       "Punch during grace cancels missed",
//       "Late punch after grace still logs missed",
//       "Zero grace fires missed at the chosen clock",
//     ],
//   },
//   {
//     reminder: "Check Out",
//     count: 9,
//     scenarios: [
//       "Disabled is not scheduled",
//       "Not checked in is not scheduled",
//       "After check-in schedules future checkout",
//       "On the minute delivers immediately",
//       "After the minute does not catch up",
//       "On-time checkout cancels notice",
//       "Still checked in after time logs on timeline",
//       "Custom earlier checkout uses that clock",
//       "Timeline stays above cards until checkout punch",
//     ],
//   },
//   {
//     reminder: "Check Out Missed",
//     count: 6,
//     scenarios: [
//       "Disabled is not scheduled",
//       "Schedules at checkout plus grace",
//       "On the grace minute delivers immediately",
//       "After grace does not catch up",
//       "Checkout cancels missed",
//       "Still checked in after grace logs missed",
//     ],
//   },
//   {
//     reminder: "Break time",
//     count: 11,
//     scenarios: [
//       "Disabled is not scheduled",
//       "Not checked in is not scheduled",
//       "After check-in schedules chosen break clock",
//       "On the minute delivers immediately",
//       "After the minute does not catch up",
//       "Starting break before reminder cancels notice",
//       "Finished earlier break still schedules later take-break",
//       "Finished earlier break still logs later take-break",
//       "Starting break at reminder time still logs",
//       "Checkout cancels take-break",
//       "Earlier break start does not hide later take-break on timeline",
//     ],
//   },
//   {
//     reminder: "Break time ended",
//     count: 9,
//     scenarios: [
//       "Disabled is not scheduled",
//       "Not on break is not scheduled",
//       "On break schedules chosen end clock",
//       "On the minute delivers immediately",
//       "Ending break on time cancels notice",
//       "Staying on break logs at the settings clock",
//       "Custom earlier end uses that clock",
//       "Second break reminds from the open break",
//       "Earlier break-end punch does not hide later reminder",
//     ],
//   },
//   {
//     reminder: "Longer break",
//     count: 5,
//     scenarios: [
//       "Disabled is not scheduled",
//       "Not on break is not scheduled",
//       "On break schedules one hour after break-end",
//       "Ending break on time skips longer-break log",
//       "Staying an hour past end logs longer-break",
//     ],
//   },
//   {
//     reminder: "Very long attendance",
//     count: 11,
//     scenarios: [
//       "Disabled is not scheduled",
//       "Not checked in is not scheduled",
//       "After check-in waits the chosen duration",
//       "On the duration minute delivers immediately",
//       "After duration still catch-up notifies while checked in",
//       "Checkout before duration skips notice",
//       "Still logs after later checkout if they stayed through it",
//       "Does not log when checkout is before the duration",
//       "Still logs while on break",
//       "Every picker from 10 minutes to 12 hours notifies and logs",
//       "Sits above cards until a checkout punch exists",
//     ],
//   },
//   {
//     reminder: "Enter / leave location",
//     count: 3,
//     scenarios: [
//       "OS plan never schedules enter or leave",
//       "Check-in logs enter location on timeline",
//       "Checkout logs leave location on timeline",
//     ],
//   },
//   {
//     reminder: "Cross-cutting",
//     count: 4,
//     scenarios: [
//       "Overnight 9 PM to 6 AM places checkout next morning",
//       "The same reminder is not logged twice",
//       "Copy exists for every reminder type",
//       "Quiet day lists missed notices above the check-in card",
//     ],
//   },
// ];

// export default function ReminderScenarioReport() {
//   const theme = useHostTheme();

//   return (
//     <Stack gap={24}>
//       <Stack gap={8}>
//         <H1>Reminder scenario report</H1>
//         <Text tone="secondary">
//           Flutter unit run of every attendance reminder file, 11 Sep 2026.
//           Matrix coverage plus existing plan, engine, toggle, clock, and
//           timezone suites.
//         </Text>
//       </Stack>

//       <Grid columns={4} gap={16}>
//         <Stat value="310" label="Tests run" />
//         <Stat value="310" label="Passed" tone="success" />
//         <Stat value="0" label="Failed" />
//         <Stat value="100%" label="Pass rate" tone="success" />
//       </Grid>

//       <Callout tone="success">
//         No failures. Check In, Check In Missed, Check Out, Check Out Missed,
//         Break time, Break time ended, Longer break, and Very long attendance
//         (10 minutes through 12 hours) all passed. Enter/leave location stays
//         timeline-only, which matches the current geofence design.
//       </Callout>

//       <H2>Results by test file</H2>
//       <Table
//         headers={["File", "Tests", "Result", "What it covers"]}
//         columnAlign={["left", "right", "left", "left"]}
//         striped
//         rows={FILES.map(([file, count, covers]) => [
//           file,
//           count,
//           "Passed",
//           covers,
//         ])}
//         rowTone={FILES.map(() => "success" as const)}
//       />
//       <Text size="small" tone="secondary">
//         Source: flutter test on reminder_*.dart · 310 cases · 0 skipped
//       </Text>

//       <H2>Matrix scenarios by reminder</H2>
//       <Text>
//         Dedicated matrix: 77 cases across every reminder type. Each bar is
//         passed scenarios for that reminder.
//       </Text>
//       <BarChart
//         height={280}
//         horizontal
//         categories={MATRIX.map((row) => row.reminder)}
//         series={[
//           {
//             name: "Passed scenarios",
//             data: MATRIX.map((row) => row.count),
//             tone: "success",
//           },
//         ]}
//       />
//       <Text size="small" tone="secondary">
//         Source: reminder_matrix_scenarios_test.dart · 77 passed · 0 failed
//       </Text>

//       <H2>Scenario checklist</H2>
//       <Text tone="secondary">
//         Every row below passed. Open a reminder to see the exact cases.
//       </Text>
//       <Stack gap={12}>
//         {MATRIX.map((row) => (
//           <Card collapsible defaultOpen={false}>
//             <CardHeader
//               trailing={
//                 <Pill active size="sm">
//                   {row.count}/{row.count} passed
//                 </Pill>
//               }
//             >
//               {row.reminder}
//             </CardHeader>
//             <CardBody style={{ padding: 0 }}>
//               <Table
//                 framed={false}
//                 headers={["Scenario", "Result"]}
//                 rows={row.scenarios.map((scenario) => [scenario, "Passed"])}
//                 rowTone={row.scenarios.map(() => "success" as const)}
//                 striped
//               />
//             </CardBody>
//           </Card>
//         ))}
//       </Stack>

//       <Text size="small" tone="secondary" style={{ color: theme.text.tertiary }}>
//         Also included outside the matrix: permission vs picked clocks, rest
//         days, overnight shifts, combined toggles, and Karachi timezone
//         scheduling. No failing cases in that set either.
//       </Text>
//     </Stack>
//   );
// }
