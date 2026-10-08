// Seeded strongly connected components of polymorphic functions (P001
// Task 5, ruling R3). test/poly-termination.test.mjs checks that the
// instantiation rule accepts them and rejects each wrapped variant; Task 8
// reuses them for the termination bound of design §4.2, so a component
// also reports its functions, arities and the ground types written at its
// intra-component references. A test file cannot export these: importing
// it would register its tests. FN001 Task 5: an edge is also written as a
// value reference or inside a lambda (design §6), each an edge as a call
// is; `kind` says which, drawn from a stream of its own so the components
// themselves are those P001 drew.
import { generator } from './generators.mjs';

const choose = (next, count) => (next() >>> 0) % count;
const variables = ['a', 'b', 'c'];
const maximumArity = 3;
const minimumSize = 2;
const sizeSpread = 3;
const extraEdges = 3;
export const componentCount = 200;

// The literal written for a ground argument and the ground type it fixes.
// `Nil` leaves its element open, a hole, which the rule counts as ground
// (§4.1) and specialization replaces by its representative, Int.
export const groundArguments = [
  { text: '1', type: 'Int' },
  { text: 'true', type: 'Bool' },
  { text: 'Cons(1, Nil)', type: 'List(Int)' },
  { text: 'Nil', type: 'List(_)' }
];

// `outside` is in a component of its own, so a call to it may wrap.
export const prelude = 'type List(a) = Nil | Cons(a, List(a));'
  + ' fn outside(x: a): Int = 0; ';
export const main = 'fn main(): Int = 0;';

// Each argument is a variable of the caller (`{ variable: q }`, the
// caller's q-th parameter, so positions permute, repeat or drop) or a
// ground argument (`{ ground: index }` into groundArguments).
const argument = (next, arity) => choose(next, 3)
  ? { variable: choose(next, arity) }
  : { ground: choose(next, groundArguments.length) };

const call = (next, functions, caller, callee) => ({
  caller, callee, arguments: Array.from(
    { length: functions[callee].arity },
    () => argument(next, functions[caller].arity))
});

// f(i) calls f(i + 1) around a cycle, so the component is strongly
// connected; extra edges (self calls included) add variety.
const draw = next => {
  const size = minimumSize + choose(next, sizeSpread);
  const functions = Array.from({ length: size }, (_, index) => (
    { name: `f${index}`, arity: 1 + choose(next, maximumArity) }));
  const calls = functions.map((_, caller) => [
    call(next, functions, caller, (caller + 1) % size),
    ...Array.from({ length: choose(next, extraEdges) },
      () => call(next, functions, caller, choose(next, size)))
  ]);
  const outside = functions.map(() => choose(next, 2) === 0);
  return { functions, calls, outside };
};

// How an edge is written: a call; the callee as a value, applied; and
// either of those inside a lambda applied at once. `at` is where the
// reference the instantiation rule reports starts within the text.
export const edgeKinds = ['call', 'value', 'lambda', 'lambdaValue'];
const lambdaOpen = '(fn(z) => ';
const written = (kind, name, args) => {
  const called = `${name}(${args})`;
  const value = `(${name})(${args})`;
  const inner = kind === 'call' || kind === 'lambda' ? called : value;
  const prefix = kind.startsWith('lambda') ? lambdaOpen : '';
  const text = kind.startsWith('lambda') ? `${prefix}${inner})(0)` : inner;
  const shift = inner === value ? 1 : 0;
  return { text, at: prefix.length + shift,
    reported: inner === value ? name : called };
};

const argumentText = value => 'variable' in value ? `x${value.variable}`
  : 'wrapped' in value ? `Cons(x${value.wrapped}, Nil)`
    : groundArguments[value.ground].text;
const callText = (functions, edge) => written(edge.kind ?? 'call',
  functions[edge.callee].name, edge.arguments.map(argumentText).join(', '));
const signature = definition => Array.from({ length: definition.arity },
  (_, index) => `x${index}: ${variables[index]}`).join(', ');

// The source, with each reference's reported text and offset, for exact
// spans; `entry`
// replaces `main` (Task 8 enters the component from it).
export const render = (component, entry = main) => {
  let source = prelude;
  const located = [];
  component.functions.forEach((definition, caller) => {
    source += `fn ${definition.name}(${signature(definition)}): Int = `;
    component.calls[caller].forEach((edge, index) => {
      if (index) source += ' + ';
      const shown = callText(component.functions, edge);
      located.push({ ...edge, text: shown.reported,
        offset: source.length + shown.at });
      source += shown.text;
    });
    if (component.outside[caller]) source += ' + outside(Cons(x0, Nil))';
    source += '; ';
  });
  return { source: source + entry, calls: located };
};

// The distinct ground types written at the component's own references.
export const groundTypes = component => [...new Set(component.calls.flat()
  .flatMap(edge => edge.arguments).filter(value => 'ground' in value)
  .map(value => groundArguments[value.ground].type))];

const withKinds = (component, next) => ({ ...component,
  calls: component.calls.map(row => row.map(edge =>
    ({ ...edge, kind: edgeKinds[choose(next, edgeKinds.length)] }))) });

export const components = (() => {
  const next = generator(0x5ca1);
  const kinds = generator(0x7a5c);
  return Array.from({ length: componentCount },
    () => withKinds(draw(next), kinds));
})();

// The same component with one argument of one intra-component call
// replaced by `Cons(x, Nil)`, whose type `List(v)` wraps a variable of the
// caller; returns it with the index of that call in `render`'s order.
export const wrapped = (component, next) => {
  const edges = component.calls.flat();
  const chosen = choose(next, edges.length);
  const edge = edges[chosen];
  const position = choose(next, edge.arguments.length);
  const arity = component.functions[edge.caller].arity;
  const replaced = { ...edge, arguments: edge.arguments.map((value, index) =>
    index === position ? { wrapped: choose(next, arity) } : value) };
  const calls = component.calls.map(row => row.map(each =>
    each === edge ? replaced : each));
  return { component: { ...component, calls }, call: chosen };
};
