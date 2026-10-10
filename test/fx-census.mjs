// The feature census of the FX001 corpus (brief Task 10, step 2): how many
// generated programs exercised each behaviour, as the reference
// interpreter observed it (not as the generator intended it), and the
// minimums a run must meet.
const scoped = 50;
const cleanup = 25;

// [name, interpreter events (any of them counts), minimum programs]
export const categories = [
  ['nested same-key handlers', ['nested-same-key', 'forward'], scoped],
  ['aborts crossing an unrelated handle', ['abort-crosses-handle'], scoped],
  ['stage order with over-application', ['over-application'], scoped],
  ['escaped callbacks under another handler', ['escaped-callback'], scoped],
  ['cleanup: normal exit', ['cleanup-exit-normal'], cleanup],
  ['cleanup: abort', ['cleanup-exit-abort'], cleanup],
  ['cleanup: defect', ['cleanup-exit-defect'], cleanup],
  ['cleanup: crash on normal exit', ['cleanup-crash-normal'], cleanup],
  ['cleanup: crash while an abort is pending', ['cleanup-crash-abort'], cleanup],
  ['cleanup: several crashes', ['cleanup-multi-crash'], cleanup],
  ['cleanup: handles its own failure during an abort',
    ['cleanup-own-fail-during-abort'], cleanup],
  ['cleanup: registration context while unwinding',
    ['cleanup-registration-context'], cleanup],
  ['cleanup: unreached defer', ['unreached-defer'], cleanup]
];

// outcomes: the interpreter outcomes of the run's programs.
export const census = outcomes => categories.map(([name, events, minimum]) => ({
  name, minimum,
  programs: outcomes.filter(found =>
    events.some(event => found.events.has(event))).length
}));

export const shortfalls = rows => rows.filter(row => row.programs < row.minimum);

export const table = rows => rows.map(row =>
  `${row.name}: ${row.programs} (minimum ${row.minimum})`).join('\n');
