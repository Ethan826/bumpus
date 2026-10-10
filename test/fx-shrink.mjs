// Shrinker for the generated FX001 programs (brief Task 10, step 3). It
// works on the generator's typed trees: drop block items (defers
// included), handlers (`with` and `handle` become their body), clauses and
// match arms, whole functions, and replace a subexpression by a literal of
// its type. A candidate is kept only if `keep` accepts it (the caller
// checks that it is still well-typed and still differs); coarse changes
// are tried first and the search restarts after each accepted one.
import { lit, truth, unit } from './fx-gen-ast.mjs';

const literalOf = node => {
  if (node.k === 'lit') return null;
  return { Int: lit(0), Unit: unit, Bool: truth }[node.ty] ?? null;
};
const without = (list, index) => list.filter((_, at) => at !== index);
const replaced = (list, index, value) => list.map((old, at) => (at === index ? value : old));

// Each way to change one child of `node` (a list of children by key).
function* inList(node, key, list, field) {
  for (const [index, entry] of list.entries()) {
    for (const changed of variants(field ? entry[field] : entry)) {
      yield { ...node, [key]: replaced(list, index,
        field ? { ...entry, [field]: changed } : changed) };
    }
  }
}
function* inChild(node, key) {
  for (const changed of variants(node[key])) yield { ...node, [key]: changed };
}

// A `with` body must stay a block, so it is not replaced by a literal.
function* inBlock(node) {
  yield* variants(node.body, false);
}

function* variants(node, replaceable = true) {
  const literal = literalOf(node);
  if (literal && replaceable) yield literal;
  switch (node.k) {
    case 'blk':
      for (let index = 0; index < node.items.length; index++) {
        yield { ...node, items: without(node.items, index) };
      }
      yield* inList(node, 'items', node.items, 'value');
      if (node.value) yield* inChild(node, 'value');
      return;
    case 'with':
      yield node.body;
      yield* inChild(node, 'handler');
      for (const body of inBlock(node)) yield { ...node, body };
      return;
    case 'handle':
      yield node.body;
      if (node.clauses.length > 1) {
        yield* node.clauses.map((_, index) =>
          ({ ...node, clauses: without(node.clauses, index) }));
      }
      yield* inList(node, 'clauses', node.clauses, 'body');
      yield* inChild(node, 'body');
      return;
    case 'handler': yield* inList(node, 'clauses', node.clauses, 'body'); return;
    case 'call': yield* inList(node, 'args', node.args); return;
    case 'app': yield* inChild(node, 'callee'); yield* inList(node, 'args', node.args); return;
    case 'add':
      yield node.left;
      yield node.right;
      yield* inChild(node, 'left');
      yield* inChild(node, 'right');
      return;
    case 'lam': yield* inChild(node, 'body'); return;
    case 'match':
      if (node.arms.length > 1) {
        yield* node.arms.map((_, index) => ({ ...node, arms: without(node.arms, index) }));
      }
      yield* inList(node, 'arms', node.arms, 'body');
      return;
    default:
  }
}

function* programVariants(program) {
  for (let index = 0; index < program.fns.length; index++) {
    yield { ...program, fns: without(program.fns, index) };
  }
  for (const body of variants(program.main.body)) {
    yield { ...program, main: { ...program.main, body } };
  }
  for (const [index, fn] of program.fns.entries()) {
    for (const body of variants(fn.body)) {
      yield { ...program, fns: replaced(program.fns, index, { ...fn, body }) };
    }
  }
}

// The smallest program found that `keep` still accepts, within `budget`
// calls of `keep`.
export const shrink = (program, keep, budget = 600) => {
  let current = program;
  let calls = 0;
  for (let progress = true; progress;) {
    progress = false;
    for (const candidate of programVariants(current)) {
      if (++calls > budget) return current;
      if (keep(candidate)) { current = candidate; progress = true; break; }
    }
  }
  return current;
};
