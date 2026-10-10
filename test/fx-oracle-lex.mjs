// Reading tools for the FX001 reference interpreter (test/fx-oracle.mjs):
// a tokenizer that knows the effect forms (`...`, `with`), a token cursor,
// and types read into { head, args } trees (the interpreter needs a type
// only to name a payload's family and to print its type). Shares no code
// with the compiler. test/poly-parse.mjs keeps its tokenizer and parser
// private, so the effect grammar needs its own.
import { isUpper } from './poly-parse.mjs';

export { isUpper };

const token = new RegExp(String.raw`\s*(?:(-\s*\d+|\d+)|`
  + String.raw`([A-Za-z_][A-Za-z0-9_]*)|`
  + String.raw`(\.\.\.|=>|==|!=|<=|>=|->|\|>|[<>(){},;:=+|]))`, 'y');

export const tokenize = source => {
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

export const cursor = tokens => {
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
  return { peek, take, list, done: () => at >= tokens.length };
};

// type := operand ('+' operand)* ('->' type)? ('with' row)?
// operand := '(' type, ... ')' | '...' name | Name ('(' type, ... ')')?
// Arrows read right to left, as `A -> B -> C` does; a row after `with` is
// a `+` chain of labels, `pure` or a spread, read and dropped.
export const typeReader = ({ peek, take, list }) => {
  const operand = () => {
    if (peek('(')) {
      take('(');
      const inner = list(type, ')');
      return inner.length === 1 ? inner[0] : { head: '()', args: inner };
    }
    if (peek('...')) { take('...'); return { head: `...${take().text}`, args: [] }; }
    const head = take().text;
    const args = peek('(') ? (take('('), list(type, ')')) : [];
    return { head, args };
  };
  const chain = () => {
    let left = operand();
    while (peek('+')) {
      take('+');
      left = { head: '+', args: [left, operand()] };
    }
    return left;
  };
  const type = () => {
    let result = chain();
    if (peek('->')) {
      take('->');
      result = { head: '->', args: [result, type()] };
    }
    if (peek('with')) { take('with'); chain(); }
    return result;
  };
  return type;
};
