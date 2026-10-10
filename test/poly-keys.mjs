// Specialization keys by source name (P001 Task 8). A key's declaration id
// becomes its function or type name, and each type id inside its arguments
// becomes that type's name, so a key reads `fn length[List(Int)]` and keys
// of two programs that number declarations differently can be compared.
// Function and type names are unique within a program. An arrow reads as
// written, `(Int -> Int) -> Bool`; its spine is walked by a loop (FN001).
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import {
  TBool, TData, TFun, THandler, TInt, TUnit
} from '../output/Domain.Type/index.js';
import { specializationKeys } from '../output/Features.Specialize/index.js';
import { checkedPoly } from './phases.mjs';

const arrowText = (program, type) => {
  const parts = [];
  let rest = type;
  for (; rest instanceof TFun; rest = rest.value2) {
    const parameter = groundText(program, rest.value0);
    parts.push(rest.value0 instanceof TFun ? `(${parameter})` : parameter);
  }
  return [...parts, groundText(program, rest)].join(' -> ');
};

const groundText = (program, type) => {
  if (type instanceof TFun) return arrowText(program, type);
  if (type instanceof TInt) return 'Int';
  if (type instanceof TBool) return 'Bool';
  if (type instanceof TUnit) return 'Unit';
  if (type instanceof THandler) {
    return `Handler(${applied(program.effects[type.value0.value0.value0].name,
      type.value0.value1.map(arg => groundText(program, arg)))})`;
  }
  // The message is built only on failure: a 5,000-parameter arrow inside
  // an application is too deep for JSON.stringify.
  if (!(type instanceof TData)) assert.fail(`not ground: ${type}`);
  return applied(program.types[type.value0].name,
    type.value1.map(arg => groundText(program, arg)));
};

const applied = (name, args) => args.length ? `${name}(${args.join(', ')})`
  : name;

// Effect keys (FX001 Task 6) name an effect; the others a type or function.
const declarations = (program, key) => key.effect ? program.effects
  : key.function ? program.functions : program.types;
const kindOf = key => key.effect ? 'effect' : key.function ? 'fn' : 'type';

// Each key as { function, effect, name, arguments (texts), text }.
export const namedKeys = source => {
  const program = checkedPoly(source);
  const result = specializationKeys(program);
  if (!(result instanceof Right)) assert.fail(`${source}\n${JSON.stringify(result)}`);
  return result.value0.map(key => {
    const name = declarations(program, key)[key.declaration].name;
    const args = key.arguments.map(arg => groundText(program, arg));
    return { function: key.function, effect: key.effect, name,
      arguments: args, text: `${kindOf(key)} ${name}[${args.join(', ')}]` };
  });
};

export const keyTexts = source => namedKeys(source).map(key => key.text);
