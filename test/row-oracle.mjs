// An independent reference for scoped-label row unification (FX001 design
// §2, Leijen 2005 §7), written from the rules alone, not from
// UnifyRow.purs: recursive, with an eagerly applied substitution, and a
// bare meta tail bound to a whole row at once (the checker extends one
// label at a time). Plain JS rows and types as in test/unify-support.mjs;
// label arguments here are Int, Bool, rigid, meta or List(...) only.

const typeHead = t => t.k === 'int' ? 'int' : t.k === 'bool' ? 'bool'
  : t.k === 'data' ? `d${t.id}` : null;

// A label's key: its effect, or Fail's payload head; null when deferred.
export const keyOf = label => {
  if (label.e !== 'fail') return `e:${label.e}`;
  const head = typeHead(label.args[0]);
  return head === null ? null : `fail:${head}`;
};

const makeState = () => ({ types: new Map(), rows: new Map(), fresh: 0 });

const applyType = (state, t) => {
  if (t.k === 'meta' && state.types.has(t.n)) return applyType(state, state.types.get(t.n));
  if (t.args) return { ...t, args: t.args.map(arg => applyType(state, arg)) };
  return t;
};

const applyRow = (state, row) => {
  const labels = row.labels.map(l => ({ ...l, args: l.args.map(a => applyType(state, a)) }));
  if (row.tail !== null && row.tail.k === 'meta' && state.rows.has(row.tail.n)) {
    const rest = applyRow(state, state.rows.get(row.tail.n));
    return { labels: [...labels, ...rest.labels], tail: rest.tail };
  }
  return { labels, tail: row.tail };
};

const containsMeta = (t, n) => t.k === 'meta' ? t.n === n
  : (t.args ?? []).some(arg => containsMeta(arg, n));

const unifyType = (state, left, right) => {
  const [l, r] = [applyType(state, left), applyType(state, right)];
  if (l.k === 'meta' || r.k === 'meta') {
    const [m, other] = l.k === 'meta' ? [l, r] : [r, l];
    if (other.k === 'meta' && other.n === m.n) return true;
    if (containsMeta(other, m.n)) return false;
    state.types.set(m.n, other);
    return true;
  }
  if (l.k !== r.k) return false;
  if (l.k === 'rigid') return l.n === r.n;
  if (l.k === 'data') {
    return l.id === r.id && l.args.every((arg, i) => unifyType(state, arg, r.args[i]));
  }
  return true;
};

const sameVariable = (a, b) => a !== null && b !== null && a.k === b.k && a.n === b.n;

const unifyTails = (state, left, right) => {
  if (left === null && right === null) return true;
  if (sameVariable(left, right)) return true;
  if (left !== null && left.k === 'meta') { state.rows.set(left.n, { labels: [], tail: right }); return true; }
  if (right !== null && right.k === 'meta') { state.rows.set(right.n, { labels: [], tail: left }); return true; }
  return false;
};

const unifyRowInto = (state, leftRow, rightRow) => {
  const [left, right] = [applyRow(state, leftRow), applyRow(state, rightRow)];
  if (left.labels.length === 0) {
    if (right.labels.length === 0) return unifyTails(state, left.tail, right.tail);
    if (left.tail === null || left.tail.k !== 'meta') return false;
    if (sameVariable(left.tail, right.tail)) return false;
    state.rows.set(left.tail.n, right);
    return true;
  }
  const [label, ...rest] = left.labels;
  const remainder = { labels: rest, tail: left.tail };
  const key = keyOf(label);
  const index = key === null ? -1 : right.labels.findIndex(other => keyOf(other) === key);
  if (index >= 0) {
    const other = right.labels[index];
    if (other.args.length !== label.args.length) return false;
    if (!label.args.every((arg, i) => unifyType(state, arg, other.args[i]))) return false;
    const without = right.labels.filter((_, i) => i !== index);
    return unifyRowInto(state, remainder, { labels: without, tail: right.tail });
  }
  if (right.tail === null || right.tail.k !== 'meta') return false;
  // The side condition: rewriting must not bind the left row's own tail.
  if (sameVariable(left.tail, right.tail)) return false;
  state.fresh += 1;
  const fresh = { k: 'meta', n: `f${state.fresh}` };
  state.rows.set(right.tail.n, { labels: [label], tail: fresh });
  return unifyRowInto(state, remainder, { labels: right.labels, tail: fresh });
};

// Null on failure, else both rows with the solution applied.
export const oracleUnifyRows = (left, right) => {
  const state = makeState();
  if (!unifyRowInto(state, left, right)) return null;
  return [applyRow(state, left), applyRow(state, right)];
};

// Scoped-label normal form: labels stably sorted by key, so distinct keys
// commute while one key's entries keep their order and multiplicity.
export const normalRow = row => ({
  labels: row.labels.map((label, index) => ({ label, index }))
    .sort((a, b) => sortKey(a) < sortKey(b) ? -1 : sortKey(a) > sortKey(b) ? 1 : 0)
    .map(entry => entry.label),
  tail: row.tail
});
const sortKey = entry => keyOf(entry.label) ?? `~deferred${entry.index}`;

// Metas renamed by first occurrence, types and rows apart, across a list.
export const canonicalRows = rows => {
  const names = { type: new Map(), row: new Map() };
  const rename = (table, n) => {
    if (!table.has(n)) table.set(n, table.size);
    return table.get(n);
  };
  const type = t => t.k === 'meta' ? { k: 'meta', n: rename(names.type, t.n) }
    : t.args ? { ...t, args: t.args.map(type) } : t;
  return rows.map(row => ({
    labels: row.labels.map(l => ({ ...l, args: l.args.map(type) })),
    tail: row.tail !== null && row.tail.k === 'meta'
      ? { k: 'meta', n: rename(names.row, row.tail.n) } : row.tail
  }));
};
