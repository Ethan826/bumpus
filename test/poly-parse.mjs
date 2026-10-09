// The surface syntax for the reference interpreter (test/poly-oracle.mjs),
// type parameters, applied and function types, lambdas, postfix
// application and pipes included (FN001). Types are read and dropped: the
// interpreter evaluates without them. Shares no code with the compiler.

// An integer (a minus belongs to its literal), a word, or punctuation.
const token = new RegExp(String.raw`\s*(?:(-\s*\d+|\d+)|`
  + String.raw`([A-Za-z_][A-Za-z0-9_]*)|`
  + String.raw`(=>|==|!=|<=|>=|->|\|>|[<>(){},;:=+|]))`, 'y');

const tokenize = source => {
  const tokens = [];
  token.lastIndex = 0;
  while (token.lastIndex < source.trimEnd().length) {
    const at = token.lastIndex;
    const found = token.exec(source);
    if (!found) throw new Error(`oracle: cannot read at ${at}`);
    const [, integer, name, punctuation] = found;
    if (integer !== undefined) {
      tokens.push({ kind: 'int', value: Number(integer.replace(/\s/g, '')) });
    } else tokens.push({ kind: 'word', text: name ?? punctuation });
  }
  return tokens;
};

export const isUpper = text => /^[A-Z]/.test(text);

// Recursive descent; returns { ctors (name → declaration position),
// fields (constructor name → field count), functions (name →
// { parameters, body }, in declaration order) }.
export const parseProgram = source => {
  const tokens = tokenize(source);
  let at = 0;
  const peek = (text, offset = 0) => tokens[at + offset]?.text === text;
  const take = text => {
    const next = tokens[at++];
    if (text !== undefined && next?.text !== text) {
      throw new Error(`oracle: expected ${text} at token ${at - 1}`);
    }
    return next;
  };
  const list = (item, close) => {
    const items = [item()];
    while (peek(',') && !peek(close, 1)) { take(','); items.push(item()); }
    if (peek(',')) take(',');
    take(close);
    return items;
  };
  // An operand, or a parenthesized list, then any further `-> operand`.
  const skipOperand = () => {
    if (!peek('(')) take();
    if (peek('(')) { take('('); list(skipType, ')'); }
  };
  const skipType = () => {
    skipOperand();
    while (peek('->')) { take('->'); skipOperand(); }
  };
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
  // `_` discards its argument: null in the parameter list.
  const lambdaParameter = () => {
    const name = take().text;
    if (peek(':')) { take(':'); skipType(); }
    return name === '_' ? null : name;
  };
  const lambda = () => {
    take('fn');
    take('(');
    const parameters = list(lambdaParameter, ')');
    take('=>');
    return { tag: 'lambda', parameters, body: expression() };
  };
  // A name directly followed by `(` is a call; each further `(…)` applies
  // the value before it.
  const atom = () => {
    let node = primary();
    while (peek('(')) {
      take('(');
      node = { tag: 'applyValue', callee: node, args: list(expression, ')') };
    }
    return node;
  };
  const primary = () => {
    const next = take();
    if (next.kind === 'int') return { tag: 'value', value: next.value };
    if (next.text === 'true' || next.text === 'false') {
      return { tag: 'value', value: next.text === 'true' };
    }
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
    return { tag: 'apply', name: next.text, args: list(expression, ')') };
  };
  const addition = () => {
    let left = atom();
    while (peek('+')) { take('+'); left = { tag: 'add', left, right: atom() }; }
    return left;
  };
  const operators = ['==', '!=', '<', '<=', '>', '>='];
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
  const expression = () => {
    if (peek('fn')) return lambda();
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
  const ctors = new Map();
  const fields = new Map();
  const functions = new Map();
  const ctor = position => {
    const name = take().text;
    fields.set(name, peek('(') ? (take('('), list(skipType, ')')).length : 0);
    ctors.set(name, position);
  };
  const typeDeclaration = () => {
    take('type');
    skipType();
    take('=');
    let position = 0;
    ctor(position);
    while (peek('|')) { take('|'); ctor(++position); }
  };
  const parameter = () => {
    const name = take().text;
    take(':');
    skipType();
    return name;
  };
  const functionDeclaration = () => {
    take('fn');
    const name = take().text;
    take('(');
    const parameters = peek(')') ? (take(')'), []) : list(parameter, ')');
    take(':');
    skipType();
    take('=');
    functions.set(name, { parameters, body: expression() });
  };
  while (at < tokens.length) {
    if (peek('type')) typeDeclaration(); else functionDeclaration();
    take(';');
  }
  return { ctors, fields, functions };
};
