// Specialization keys by source name (P001 Task 8). A key's declaration id
// becomes its function or type name, and each type id inside its arguments
// becomes that type's name, so a key reads `fn length[List(Int)]` and keys
// of two programs that number declarations differently can be compared.
// Function and type names are unique within a program. An arrow reads as
// written, `(Int -> Int) -> Bool`; its spine is walked by a loop (FN001).
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import {
  TBool, TData, TFun, TInt
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
  assert.ok(type instanceof TData, `not ground: ${JSON.stringify(type)}`);
  const name = program.types[type.value0].name;
  const args = type.value1.map(arg => groundText(program, arg));
  return args.length ? `${name}(${args.join(', ')})` : name;
};

// Each key as { function, name, arguments (texts), text }.
export const namedKeys = source => {
  const program = checkedPoly(source);
  const result = specializationKeys(program);
  if (!(result instanceof Right)) assert.fail(`${source}\n${JSON.stringify(result)}`);
  return result.value0.map(key => {
    const name = (key.function ? program.functions : program.types)[
      key.declaration].name;
    const args = key.arguments.map(arg => groundText(program, arg));
    const kind = key.function ? 'fn' : 'type';
    return { function: key.function, name, arguments: args,
      text: `${kind} ${name}[${args.join(', ')}]` };
  });
};

export const keyTexts = source => namedKeys(source).map(key => key.text);
