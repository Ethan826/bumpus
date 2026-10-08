// FN001 Task 5's lambda wrappers for the representative-independence
// property, shared by test/fn-representative.test.mjs (on the IR) and
// test/fn-run.test.mjs (executed, Task 6). Each generated P001 program has
// every body wrapped in a lambda whose unused parameters are holes:
// applied at once to `Nil` (a parameter of type `List(_)`), or never
// applied (parameters of bare hole type) and matched on.
const wrappers = [
  body => `(fn(unusedParameter) => ${body})(Nil)`,
  body => `match (fn(unusedParameter, _) => 0) { _ => ${body} }`,
  body => `(fn(_, unusedParameter) => ${body})(Nil, Nil)`
];

// Every function declaration's body is the text after its first ` = `
// (type texts hold no `=`) up to its `;` (expressions hold none).
export const withLambdas = source => source.split('; ')
  .map((declaration, index) => {
    if (!declaration.startsWith('fn ')) return declaration;
    const split = declaration.indexOf(' = ') + ' = '.length;
    const end = declaration.endsWith(';') ? -1 : declaration.length;
    const wrap = wrappers[index % wrappers.length];
    return declaration.slice(0, split)
      + wrap(declaration.slice(split, end)) + declaration.slice(end);
  }).join('; ');
