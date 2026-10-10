// Typed syntax trees of the generated FX001 programs, and their printer.
// Each node carries `ty` ('Int', 'Unit', 'Bool', 'Err', 'Oops' or 'fn') so
// the shrinker can replace a subexpression by a literal of its type.
// Blocks are { items, value }: an item is { k: 'let' | 'do' | 'defer', ... };
// a null value makes the block Unit (printed with a trailing `;`).
export const lit = number => ({ k: 'lit', text: String(number), ty: 'Int' });
export const unit = { k: 'lit', text: '()', ty: 'Unit' };
export const truth = { k: 'lit', text: 'true', ty: 'Bool' };
export const local = (name, ty = 'Int') => ({ k: 'var', name, ty });
export const call = (name, args, ty) => ({ k: 'call', name, args, ty });
export const apply = (callee, args, ty) => ({ k: 'app', callee, args, ty });
export const add = (left, right) => ({ k: 'add', left, right, ty: 'Int' });
export const lambda = (params, body) => ({ k: 'lam', params, body, ty: 'fn' });
export const block = (items, value = null) => ({ k: 'blk', items, value, ty: value?.ty ?? 'Unit' });
export const withHandler = (handler, body) => ({ k: 'with', handler, body, ty: body.ty });
export const handler = (effect, clauses) => ({ k: 'handler', effect, clauses, ty: 'handler' });
export const handle = (body, clauses) => ({ k: 'handle', body, clauses, ty: clauses[0].body.ty });
export const match = (scrutinee, arms, ty) => ({ k: 'match', scrutinee, arms, ty });

export const letItem = (name, value) => ({ k: 'let', name, value });
export const doItem = value => ({ k: 'do', value });
export const deferItem = value => ({ k: 'defer', value });

export const print = value => call('print', [value], 'Unit');
export const log = value => call('log', [value], 'Unit');
export const tick = value => call('tick', [value], 'Int');
export const crash = value => call('crash', [value], 'Unit');
export const fail = payload => call('fail', [payload], 'Unit');
export const err = number => (number < 0 ? call('Err2', [], 'Err')
  : call('Err1', [lit(number)], 'Err'));
export const oops = number => call('Oops', [lit(number)], 'Oops');

const atomic = node => ['lit', 'var', 'call', 'app'].includes(node.k);
const operand = node => (atomic(node) ? text(node) : `(${text(node)})`);
const piece = item => (item.k === 'let' ? `let ${item.name} = ${text(item.value)};`
  : `${item.k === 'defer' ? 'defer ' : ''}${text(item.value)};`);
const body = node => [...node.items.map(piece),
  ...(node.value ? [text(node.value)] : [])].join(' ');

const clause = ({ op, params, body }) => `${op}(${params.join(', ')}) => ${text(body)}`;
const failure = ({ family, name, body }) =>
  `fail(${name}: ${family}) => ${text(body)}`;
const arm = ({ pattern, body }) => `${pattern} => ${text(body)}`;

export const text = node => {
  switch (node.k) {
    case 'lit': return node.text;
    case 'var': return node.name;
    case 'call': return node.args.length === 0 && /^[A-Z]/.test(node.name)
      ? node.name : `${node.name}(${node.args.map(text).join(', ')})`;
    case 'app': return `${node.callee.k === 'lam' ? `(${text(node.callee)})`
      : text(node.callee)}(${node.args.map(text).join(', ')})`;
    case 'add': return `${operand(node.left)} + ${operand(node.right)}`;
    case 'lam': return `fn(${node.params.join(', ')}) => ${text(node.body)}`;
    case 'blk': return body(node) === '' ? '{}' : `{ ${body(node)} }`;
    case 'with': return `with ${text(node.handler)} ${text(node.body)}`;
    case 'handler': return `handler ${node.effect} { ${node.clauses.map(clause).join(', ')} }`;
    case 'handle': return `handle ${text(node.body)} { ${node.clauses.map(failure).join(', ')} }`;
    case 'match': return `match ${text(node.scrutinee)} { ${node.arms.map(arm).join(', ')} }`;
    default: throw new Error(`unknown node ${node.k}`);
  }
};
