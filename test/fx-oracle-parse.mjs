// The surface syntax for the FX001 reference interpreter: the language of
// test/poly-parse.mjs (blocks, `let`, lambdas, postfix application, pipes,
// `match`, `if`) plus effect declarations, `handler`, `with`, `handle` and
// `defer`. Returns { ctors, fields, types (by name), owner (constructor →
// type), functions, ops }. Types are read
// into trees (test/fx-oracle-lex.mjs) and mostly dropped. Shares no code
// with the compiler.
import { cursor, isUpper, tokenize, typeReader } from './fx-oracle-lex.mjs';
import { unit } from './poly-parse.mjs';

const unitNode = { tag: 'value', value: unit };
const operators = ['==', '!=', '<', '<=', '>', '>='];

const expressions = reader => {
  const { peek, take, list } = reader;
  const readType = typeReader(reader);
  const pattern = () => {
    const next = take();
    if (next.kind === 'int') return { tag: 'literal', value: next.value };
    if (next.text === 'true' || next.text === 'false') {
      return { tag: 'literal', value: next.text === 'true' };
    }
    if (next.text === '_') return { tag: 'wildcard' };
    if (!isUpper(next.text)) return { tag: 'bind', name: next.text };
    const fields = peek('(') ? (take('('), list(pattern, ')')) : [];
    return { tag: 'ctor', name: next.text, fields };
  };
  const arm = () => {
    const matched = pattern();
    take('=>');
    return { pattern: matched, body: expression() };
  };
  const parameter = () => {
    const name = take().text;
    if (peek(':')) { take(':'); readType(); }
    return name === '_' ? null : name;
  };
  const lambda = () => {
    take('fn');
    take('(');
    const parameters = peek(')') ? (take(')'), []) : list(parameter, ')');
    take('=>');
    return { tag: 'lambda', parameters, body: expression() };
  };
  const atom = () => {
    let node = primary();
    while (peek('(')) {
      take('(');
      const args = peek(')') ? (take(')'), []) : list(expression, ')');
      node = { tag: 'applyValue', callee: node, args };
    }
    return node;
  };
  const primary = () => {
    const next = take();
    if (next.kind === 'int') return { tag: 'value', value: next.value };
    if (next.text === 'true' || next.text === 'false') {
      return { tag: 'value', value: next.text === 'true' };
    }
    if (next.text === '(' && peek(')')) { take(')'); return unitNode; }
    if (next.text === '(') {
      const inner = expression();
      take(')');
      return inner;
    }
    if (!peek('(')) {
      return isUpper(next.text) ? { tag: 'apply', name: next.text, args: [] }
        : { tag: 'local', name: next.text };
    }
    take('(');
    const args = peek(')') ? (take(')'), []) : list(expression, ')');
    return { tag: 'apply', name: next.text, args };
  };
  const addition = () => {
    let left = atom();
    while (peek('+')) { take('+'); left = { tag: 'add', left, right: atom() }; }
    return left;
  };
  const comparison = () => {
    const left = addition();
    if (!operators.some(operator => peek(operator))) return left;
    const operator = take().text;
    return { tag: 'compare', operator, left, right: addition() };
  };
  const pipeline = () => {
    let left = comparison();
    while (peek('|>')) {
      take('|>');
      left = { tag: 'pipe', left, right: comparison() };
    }
    return left;
  };
  const item = () => {
    if (peek('defer')) { take('defer'); return { tag: 'defer', value: expression() }; }
    if (!peek('let')) return { tag: 'discard', value: expression() };
    take('let');
    const name = take().text;
    take('=');
    return { tag: 'let', name: name === '_' ? null : name,
      value: expression() };
  };
  const block = () => {
    take('{');
    if (peek('}')) { take('}'); return unitNode; }
    const items = [];
    for (;;) {
      const found = item();
      if (!peek(';')) {
        take('}');
        if (found.tag !== 'discard') throw new Error('oracle: expected ;');
        return { tag: 'block', items, value: found.value };
      }
      take(';');
      items.push(found);
      if (peek('}')) {
        take('}');
        return { tag: 'block', items, value: unitNode };
      }
    }
  };
  const handlerClause = () => {
    const name = take().text;
    take('(');
    const parameters = peek(')') ? (take(')'), []) : list(parameter, ')');
    take('=>');
    return { name, parameters, body: expression() };
  };
  const failClause = () => {
    take('fail');
    take('(');
    const name = take().text;
    take(':');
    const head = readType().head;
    take(')');
    take('=>');
    return { head, name, body: expression() };
  };
  const expression = () => {
    if (peek('{')) return block();
    if (peek('fn')) return lambda();
    if (peek('handler')) {
      take('handler');
      const effect = readType().head;
      take('{');
      return { tag: 'handler', effect, clauses: list(handlerClause, '}') };
    }
    if (peek('with')) {
      take('with');
      const handler = expression();
      return { tag: 'with', handler, body: block() };
    }
    if (peek('handle')) {
      take('handle');
      const body = expression();
      take('{');
      return { tag: 'handle', body, clauses: list(failClause, '}') };
    }
    if (peek('if')) {
      take('if');
      const condition = expression();
      take('then');
      const yes = expression();
      take('else');
      return { tag: 'if', condition, yes, no: expression() };
    }
    if (!peek('match')) return pipeline();
    take('match');
    const scrutinee = expression();
    take('{');
    return { tag: 'match', scrutinee, arms: list(arm, '}') };
  };
  return { expression, parameter, readType };
};

export const parseProgram = source => {
  const reader = cursor(tokenize(source));
  const { peek, take, list } = reader;
  const { expression, readType } = expressions(reader);
  const program = { ctors: new Map(), fields: new Map(), types: new Map(),
    owner: new Map(), functions: new Map(), ops: new Map() };
  const typed = () => {
    const name = take().text;
    take(':');
    readType();
    return name;
  };
  const parameters = () => (peek(')') ? (take(')'), []) : list(typed, ')'));
  const constructor = (type, position) => {
    const name = take().text;
    const fields = peek('(') ? (take('('), list(readType, ')')) : [];
    program.fields.set(name, fields.length);
    program.ctors.set(name, position);
    type.ctors.push({ name, fields });
    program.owner.set(name, type);
  };
  const typeDeclaration = () => {
    take('type');
    const head = readType();
    take('=');
    const type = { name: head.head, params: head.args.map(arg => arg.head),
      ctors: [] };
    program.types.set(type.name, type);
    constructor(type, 0);
    for (let position = 1; peek('|'); position++) { take('|'); constructor(type, position); }
  };
  const operation = effect => {
    take('fn');
    const name = take().text;
    take('(');
    const count = parameters().length;
    take(':');
    readType();
    take(';');
    program.ops.set(name, { effect, arity: count });
  };
  const effectDeclaration = () => {
    take('effect');
    const effect = readType().head;
    take('{');
    while (!peek('}')) operation(effect);
    take('}');
  };
  const functionDeclaration = () => {
    take('fn');
    const name = take().text;
    take('(');
    const params = parameters();
    take(':');
    readType();
    take('=');
    program.functions.set(name, { parameters: params, body: expression() });
  };
  while (!reader.done()) {
    if (peek('type')) typeDeclaration();
    else if (peek('effect')) effectDeclaration();
    else functionDeclaration();
    take(';');
  }
  return program;
};
