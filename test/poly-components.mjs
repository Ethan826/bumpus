// Seeded strongly connected components of polymorphic functions (P001
// Task 5, ruling R3). test/poly-termination.test.mjs checks that the
// instantiation rule accepts them and rejects each wrapped variant; Task 8
// reuses them for the termination bound of design §4.2, so a component
// also reports its functions, arities and the ground types written at its
// intra-component references. A test file cannot export these: importing
// it would register its tests.
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

const argumentText = value => 'variable' in value ? `x${value.variable}`
  : 'wrapped' in value ? `Cons(x${value.wrapped}, Nil)`
    : groundArguments[value.ground].text;
const callText = (functions, edge) => `${functions[edge.callee].name}(`
  + `${edge.arguments.map(argumentText).join(', ')})`;
const signature = definition => Array.from({ length: definition.arity },
  (_, index) => `x${index}: ${variables[index]}`).join(', ');

// The source, with each call's text and offset, for exact spans; `entry`
// replaces `main` (Task 8 enters the component from it).
export const render = (component, entry = main) => {
  let source = prelude;
  const located = [];
  component.functions.forEach((definition, caller) => {
    source += `fn ${definition.name}(${signature(definition)}): Int = `;
    component.calls[caller].forEach((edge, index) => {
      if (index) source += ' + ';
      const text = callText(component.functions, edge);
      located.push({ ...edge, text, offset: source.length });
      source += text;
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

export const components = (() => {
  const next = generator(0x5ca1);
  return Array.from({ length: componentCount }, () => draw(next));
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
