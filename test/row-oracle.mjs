// Independent reference for scoped-label equality (design §2). Recursive
// eager substitution and backtracking transactions rather than the
// checker's explicit-stack rewrite and triangular substitution. A deferred key suspends the
// whole equation transaction; later type information can retry it.
import { applyRow, applyType, copyState, makeState, occurs, unifyType } from './row-oracle-types.mjs';
const typeHead = t => t.k === 'int' ? 'int' : t.k === 'bool' ? 'bool'
  : t.k === 'unit' ? 'unit' : t.k === 'data' ? `d${t.id}` : null;
export const keyOf = label => {
  if (label.e !== 'fail') return `e:${label.e}`;
  const head = typeHead(label.args[0]);
  return head === null ? null : `fail:${head}`;
};
const sameVariable = (a, b) => a !== null && b !== null && a.k === b.k && a.n === b.n;
const bindRow = (state, tail, row) => {
  if (row.labels.some(label => label.args.some(arg => occurs('row', tail.n, applyType(state, arg)))))
    return false;
  state.rows.set(tail.n, row);
  return true;
};
const unifyTails = (state, left, right) => {
  if (left === null && right === null || sameVariable(left, right)) return true;
  if (left?.k === 'meta') return bindRow(state, left, { labels: [], tail: right });
  if (right?.k === 'meta') return bindRow(state, right, { labels: [], tail: left });
  return false;
};
const unifyRowInto = (state, leftRow, rightRow) => {
  const [left, right] = [applyRow(state, leftRow), applyRow(state, rightRow)];
  if (left.labels.length === 0) {
    if (right.labels.length === 0) return unifyTails(state, left.tail, right.tail) ? 'solved' : 'failed';
    if (keyOf(right.labels[0]) === null) return 'pending';
    if (left.tail?.k !== 'meta' || sameVariable(left.tail, right.tail)) return 'failed';
    // Preserve incremental decision order for any later deferred entry.
    const [label, ...rest] = right.labels;
    const fresh = { k: 'meta', n: `f${++state.fresh}` };
    if (!bindRow(state, left.tail, { labels: [label], tail: fresh })) return 'failed';
    return unifyRowInto(state, { labels: [], tail: fresh }, { labels: rest, tail: right.tail });
  }
  const [label, ...rest] = left.labels;
  const remainder = { labels: rest, tail: left.tail };
  const key = keyOf(label);
  if (key === null) return 'pending';
  for (let index = 0; index < right.labels.length; index += 1) {
    const other = right.labels[index];
    const otherKey = keyOf(other);
    if (otherKey === null) return 'pending';
    if (otherKey !== key) continue;
    if (other.args.length !== label.args.length) return 'failed';
    if (!label.args.every((arg, i) => unifyType(state, arg, other.args[i], transaction))) return 'failed';
    const without = right.labels.filter((_, i) => i !== index);
    return unifyRowInto(state, remainder, { labels: without, tail: right.tail });
  }
  if (right.tail?.k !== 'meta' || sameVariable(left.tail, right.tail)) return 'failed';
  const fresh = { k: 'meta', n: `f${++state.fresh}` };
  if (!bindRow(state, right.tail, { labels: [label], tail: fresh })) return 'failed';
  return unifyRowInto(state, remainder, { labels: right.labels, tail: fresh });
};
const transaction = (state, left, right) => {
  const trial = copyState(state);
  const status = unifyRowInto(trial, left, right);
  if (status === 'solved') Object.assign(state, trial);
  if (status === 'pending') state.pending.push({ left, right });
  return status;
};
export const oracleAttempt = (left, right, seed) => {
  const state = makeState(seed);
  if (transaction(state, left, right) === 'failed') return null;
  return { rows: [applyRow(state, left), applyRow(state, right)], state };
};
export const oracleSettle = (original, types = new Map()) => {
  const state = copyState(original);
  for (const [n, type] of types) {
    if (!unifyType(state, { k: 'meta', n }, type, transaction)) return null;
  }
  let progressed;
  do {
    const pending = state.pending;
    state.pending = [];
    progressed = false;
    for (const pair of pending) {
      const status = transaction(state, pair.left, pair.right);
      if (status === 'failed') return null;
      progressed ||= status === 'solved';
    }
  } while (progressed);
  return state;
};
// Compatibility for the original solved-row properties: only solved
// equations produce an equality witness; pending is never solved equality.
export const oracleUnifyRows = (left, right) => {
  const result = oracleAttempt(left, right);
  return result === null || result.state.pending.length > 0 ? null : result.rows;
};
export const normalRow = row => ({
  labels: row.labels.map((label, index) => ({ label, index }))
    .sort((a, b) => sortKey(a) < sortKey(b) ? -1 : sortKey(a) > sortKey(b) ? 1 : 0)
    .map(entry => entry.label),
  tail: row.tail
});
const sortKey = entry => keyOf(entry.label) ?? `~deferred${entry.index}`;
export const canonicalRows = rows => {
  const names = { type: new Map(), row: new Map() };
  const rename = (table, n) => {
    if (!table.has(n)) table.set(n, table.size);
    return table.get(n);
  };
  const type = t => {
    if (t.k === 'meta') return { k: 'meta', n: rename(names.type, t.n) };
    const result = t.args ? { ...t, args: t.args.map(type) } : t;
    if (t.row) result.row = oneRow(t.row);
    if (t.rows) result.rows = t.rows.map(oneRow);
    return result;
  };
  const oneRow = row => ({
    labels: row.labels.map(l => ({ ...l, args: l.args.map(type) })),
    tail: row.tail?.k === 'meta' ? { k: 'meta', n: rename(names.row, row.tail.n) } : row.tail
  });
  return rows.map(oneRow);
};
export { applyRow };
