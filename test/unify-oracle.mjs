// An independent reference unifier for test/unify.test.mjs: union-find over
// plain JS types, written from the rules alone, not from Unify.purs.
// Types: { k: 'int' } | { k: 'bool' } | { k: 'data', id, args }
//      | { k: 'fun', args: [parameter, result] }
//      | { k: 'rigid', n } | { k: 'meta', n }.
// An arrow is one more two-argument constructor here: the oracle has no
// depth bound, so it needs no parameter/result distinction.
// Each meta is a node; a class of metas has one root, which may hold a type.

const metaKey = n => `m${n}`;

const makeState = () => ({ parent: new Map(), bound: new Map() });

const root = (state, key) => {
  let current = key;
  while (state.parent.has(current)) current = state.parent.get(current);
  return current;
};

// Follow a meta to its class's type, or to its root meta if unbound.
const head = (state, type) => {
  if (type.k !== 'meta') return type;
  const key = root(state, metaKey(type.n));
  return state.bound.get(key) ?? { k: 'meta', n: Number(key.slice(1)) };
};

// Does the class `key` occur anywhere inside `type` (through bindings)?
const occurs = (state, key, type) => {
  const pending = [type];
  while (pending.length > 0) {
    const current = head(state, pending.pop());
    if (current.k === 'meta' && metaKey(current.n) === key) return true;
    if (current.args) pending.push(...current.args);
  }
  return false;
};

const bindMeta = (state, meta, type) => {
  const key = metaKey(meta.n);
  if (type.k === 'meta') {
    if (metaKey(type.n) !== key) state.parent.set(key, metaKey(type.n));
    return true;
  }
  if (occurs(state, key, type)) return false;
  state.bound.set(key, type);
  return true;
};

const unifyInto = (state, left, right) => {
  const pending = [[left, right]];
  while (pending.length > 0) {
    const [l, r] = pending.pop().map(type => head(state, type));
    if (l.k === 'meta') { if (!bindMeta(state, l, r)) return false; continue; }
    if (r.k === 'meta') { if (!bindMeta(state, r, l)) return false; continue; }
    if (l.k !== r.k) return false;
    if (l.k === 'rigid' && l.n !== r.n) return false;
    if (l.k === 'data' && (l.id !== r.id || l.args.length !== r.args.length)) {
      return false;
    }
    if (l.args) l.args.forEach((arg, index) => pending.push([arg, r.args[index]]));
  }
  return true;
};

// The fully substituted type under the current classes.
const settle = (state, type) => {
  const current = head(state, type);
  if (!current.args) return current;
  return { ...current, args: current.args.map(arg => settle(state, arg)) };
};

// Unify each pair in turn; null on failure, else every pair's settled type.
export const oracleUnify = pairs => {
  const state = makeState();
  for (const [left, right] of pairs) {
    if (!unifyInto(state, left, right)) return null;
  }
  return pairs.map(([left]) => settle(state, left));
};

// Renumber metas by first occurrence, so equal-up-to-renaming types compare
// equal. `names` is shared across a list of types.
export const canonical = (types, names = new Map()) => types.map(type => {
  if (type.k === 'meta') {
    if (!names.has(type.n)) names.set(type.n, names.size);
    return { k: 'meta', n: names.get(type.n) };
  }
  if (!type.args) return type;
  return { ...type, args: canonical(type.args, names) };
});
