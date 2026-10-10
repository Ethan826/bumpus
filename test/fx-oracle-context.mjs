// Evaluation helpers of the FX001 reference interpreter (test/fx-oracle.mjs):
// pattern matching, comparison operators and the context chain. A context
// frame is { kind: 'with' | 'fail', key, outer, ... }, innermost first.
export const comparisons = {
  '==': order => order === 0, '!=': order => order !== 0,
  '<': order => order < 0, '<=': order => order <= 0,
  '>': order => order > 0, '>=': order => order >= 0
};
export const builtins = new Set(['print', 'crash', 'fail']);

export const matches = (pattern, value, bound) => {
  if (pattern.tag === 'wildcard') return true;
  if (pattern.tag === 'bind') { bound.set(pattern.name, value); return true; }
  if (pattern.tag === 'literal') return pattern.value === value;
  return pattern.name === value.ctor && pattern.fields.every(
    (field, index) => matches(field, value.fields[index], bound));
};

export const find = (ctx, kind, key) => {
  for (let frame = ctx; frame; frame = frame.outer) {
    if (frame.kind === kind && frame.key === key) return frame;
  }
  return null;
};
export const count = (ctx, key) => {
  let found = 0;
  for (let frame = ctx; frame; frame = frame.outer) {
    if (frame.kind === 'with' && frame.key === key) found++;
  }
  return found;
};
