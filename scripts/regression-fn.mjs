// FN001 regression rows, imported by scripts/regression.mjs; their probes
// are in test/regression-fn.mjs. Each replacement is a whole defect that
// still compiles: the lowering mutants emit Go that builds, so the probe
// fails on behavior (which body runs first, what prints), not on a build.

// `<code>` with the value awaiting `x0` of type `arrow` (an interned
// arrow whose result is again an arrow) eta-expanded to two parameters:
// applying it to one argument no longer applies `<code>`.
const eta = (indent, arrow, code, guard = '') => [
  `case ${arrow} of`,
  '  IR.TFun (IR.FunTypeId index)',
  '    | [ outer ] ← Array.fromFoldable',
  '        (Array.index scope.shape.funTypes index)',
  '    , IR.TFun (IR.FunTypeId second) ← outer.result',
  '    , [ rest ] ← Array.fromFoldable',
  `        (Array.index scope.shape.funTypes second)${guard} →`,
  '        "func(x0 " <> goType outer.parameter <> ") "',
  '          <> goType outer.result <> " { return func(x1 "',
  '          <> goType rest.parameter <> ") " <> goType rest.result',
  `          <> " { return " <> ${code} <> "(x0)(x1) } }"`
].join(`\n${indent}`);

export const fnRows = [
  {
    // A named value lowered by its type's arity, through an eta adapter,
    // rather than its declared arity (design §4): `f(1)` must enter stuck.
    name: 'stage-value', file: 'src/Format/Go/Expression.purs',
    needle: '  IR.FunctionRef id → reference next (functionWrapper scope.shape id)',
    replacement: '  IR.FunctionRef id → '
      + eta('  ', 'term.ty', '(functionWrapper scope.shape id).name',
        '\n      , Array.length (functionWrapper scope.shape id).parameters'
        + ' == 1')
        .replace('"func(x0', 'leaf next ("func(x0') + ')\n'
      + '    _ → reference next (functionWrapper scope.shape id)',
    probe: 'stage-value', message: /named value staged by its type/
  },
  {
    // A lambda's stage chain extended to its type's full arity.
    name: 'stage-lambda', file: 'src/Format/Go/Lambda.purs',
    needle: '    head { code = name, wrappers = inner.wrappers }',
    replacement: '    '
      + eta('    ', 'IR.typeOf lambda', 'name')
        .replace('"func(x0', 'head { code = "func(x0')
        + ', wrappers = inner.wrappers }\n'
      + '      _ → head { code = name, wrappers = inner.wrappers }',
    probe: 'stage-lambda', message: /lambda staged by its type/
  },
  {
    // A partial application's arguments evaluated inside the closure
    // that awaits the next argument, not when the partial is made.
    name: 'partial-strict', file: 'src/Format/Go/Value.purs',
    needle: '    applied scope lower { head: staged next wrapper, types }'
      + ' arguments\n',
    replacement: '    let\n'
      + '      eager = applied scope lower { head: staged next wrapper,'
      + ' types } arguments\n'
      + '      awaited = joinWith "" (map goType (Array.fromFoldable\n'
      + '        (Array.index wrapper.parameters (Array.length arguments))))\n'
      + '      after = joinWith "" (Array.drop 1\n'
      + '        (walked scope.shape.funTypes ty 1))\n'
      + '    in eager { code = "func(x " <> awaited <> ") " <> after\n'
      + '      <> " { return " <> eager.code <> "(x) }" }\n',
    probe: 'partial-strict', message: /partial arguments evaluated late/
  },
  {
    // Every pipe lowered as the rewritten call `g(b, a)`.
    name: 'pipe-order', file: 'src/Format/Go/Pipe.purs',
    needle: 'if effectless left then lower next',
    replacement: 'if true then lower next',
    probe: 'pipe-order', message: /pipe evaluated its left operand late/
  },
  {
    // Capture leaves a lambda's own parameters free.
    name: 'lambda-capture', file: 'src/Format/Go/Capture.purs',
    needle: '  free local = not (Set.member (index local.id) bound)',
    replacement: '  free _ = true',
    probe: 'lambda-capture', message: /lambda parameter captured/
  },
  {
    name: 'fun-compare', file: 'src/Features/Check/Comparable.purs',
    needle: 'else if containsFunction functions ty then',
    replacement: 'else if false then',
    probe: 'fun-compare', message: /function comparison accepted/
  },
  {
    // A helper evaluates its whole block of arguments, then applies.
    name: 'block-order', file: 'src/Format/Go/Apply.purs',
    needle: '    <> " {\\nreturn waxwingValue"\n'
      + '    <> joinWith "" (map (parenthesized context) parts.codes)',
    replacement: '    <> " {\\n"\n'
      + '    <> joinWith "" (Array.mapWithIndex (\\i c → "var waxwingArg"\n'
      + '      <> show i <> " " <> joinWith "" (map (goType <<< IR.typeOf)\n'
      + '        (Array.fromFoldable (Array.index (Array.slice first\n'
      + '          (first + blockSize) arguments) i))) <> " = " <> c <> "\\n")\n'
      + '        parts.codes)\n'
      + '    <> "return waxwingValue"\n'
      + '    <> joinWith "" (Array.mapWithIndex (\\i _ → "(waxwingArg" <> show i\n'
      + '      <> ")") parts.codes)',
    probe: 'block-order', message: /helper evaluated its block early/
  },
  {
    // Bare references and references inside lambdas are not edges.
    name: 'value-edge', file: 'src/Features/Check/Instantiation.purs',
    needle: '  Checked.FunctionRef id instantiation →\n'
      + '    step found expression.span id instantiation\n'
      + '  Checked.Lambda _ body → recur found body\n',
    replacement: '',
    probe: 'value-edge', message: /recursion through a lambda accepted/
  },
  {
    // Functional returns only its seeds, without the fixed point.
    name: 'functional-fixpoint', file: 'src/Features/Check/Functional.purs',
    needle: 'else spread ctors seeds',
    replacement: 'else Set.fromFoldable seeds',
    probe: 'functional-fixpoint', message: /indirectly functional type/
  },
  {
    // Arrows interned by their result only, without their parameter.
    name: 'arrow-key', file: 'src/Features/Specialize/Intern.purs',
    needle: '  pair = Tuple parameter spun.ty',
    replacement: '  pair = Tuple IR.TInt spun.ty',
    probe: 'arrow-key', message: /arrow keys merged/
  }
];
