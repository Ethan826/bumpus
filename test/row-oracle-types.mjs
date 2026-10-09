// Independent oracle's eager substitutions and structural type equations.
// No production imports: both rows and types use the plain test notation.
export const makeState = (seed = {}) => ({ types: new Map(seed.types),
  rows: new Map(seed.rows), fresh: seed.fresh ?? 0, pending: [...(seed.pending ?? [])] });
export const copyState = state => makeState(state);

export const applyType = (state, t) => {
  if (t.k === 'meta' && state.types.has(t.n)) return applyType(state, state.types.get(t.n));
  const result = t.args ? { ...t, args: t.args.map(arg => applyType(state, arg)) } : t;
  if (t.row) result.row = applyRow(state, t.row);
  if (t.rows) result.rows = t.rows.map(row => applyRow(state, row));
  return result;
};
export const applyRow = (state, row) => {
  const labels = row.labels.map(l => ({ ...l, args: l.args.map(a => applyType(state, a)) }));
  if (row.tail?.k === 'meta' && state.rows.has(row.tail.n)) {
    const rest = applyRow(state, state.rows.get(row.tail.n));
    return { labels: [...labels, ...rest.labels], tail: rest.tail };
  }
  return { labels, tail: row.tail };
};
const emptyRow = { labels: [], tail: null };
const typeRows = t => [...(t.rows ?? []), ...(t.k === 'fun' ? [t.row ?? emptyRow] : [])];
export const occurs = (sort, n, t) =>
  (sort === 'type' && t.k === 'meta' && t.n === n)
  || (t.args ?? []).some(arg => occurs(sort, n, arg))
  || typeRows(t).some(row => (sort === 'row' && row.tail?.k === 'meta' && row.tail.n === n)
    || row.labels.some(label => label.args.some(arg => occurs(sort, n, arg))));

export const unifyType = (state, left, right, unifyRows) => {
  const [l, r] = [applyType(state, left), applyType(state, right)];
  if (l.k === 'meta' || r.k === 'meta') {
    const [m, other] = l.k === 'meta' ? [l, r] : [r, l];
    if (other.k === 'meta' && other.n === m.n) return true;
    if (occurs('type', m.n, other)) return false;
    state.types.set(m.n, other);
    return true;
  }
  if (l.k !== r.k) return false;
  if (l.k === 'rigid') return l.n === r.n;
  if (l.k === 'data' && l.id !== r.id) return false;
  if (l.k === 'data' || l.k === 'fun') {
    if (l.args.length !== r.args.length) return false;
    // Arrow row equality sits between parameter and result equality.
    if (l.k === 'fun') return unifyType(state, l.args[0], r.args[0], unifyRows)
      && unifyRows(state, l.row ?? emptyRow, r.row ?? emptyRow) !== 'failed'
      && unifyType(state, l.args[1], r.args[1], unifyRows);
    if (!l.args.every((arg, i) => unifyType(state, arg, r.args[i], unifyRows))) return false;
    const [ls, rs] = [l.rows ?? [], r.rows ?? []];
    return ls.length === rs.length
      && ls.every((row, i) => unifyRows(state, row, rs[i]) !== 'failed');
  }
  return true;
};
