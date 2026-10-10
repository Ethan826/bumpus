import assert from 'node:assert/strict';

const duplicateScanTiming = ({ compile, Left, wire }) => {
  const main = ' fn main(): Int = 0;';
  const manyTypes = Array.from({ length: 20000 }, (_, index) =>
    `type T${index} = C${index};`).join(' ');
  const sources = [
    `${manyTypes} type T7 = X;${main}`,
    `${manyTypes} type X = C7;${main}`,
    `fn C7(): Int = 0; ${manyTypes}${main}`
  ];
  const started = performance.now();
  sources.forEach(source => {
    const result = compile(source);
    assert.ok(result instanceof Left, 'duplicate source was accepted');
    assert.equal(wire(result.value0).code, 'E_DUPLICATE');
  });
  const seconds = (performance.now() - started) / 1000;
  assert.ok(seconds < 5, `large-source duplicate regression took ${seconds}s`);
  console.log(`large-source duplicate timing: ${seconds}s`);
};

// FX009: a Fail payload without a family key is E_TYPE at the annotation
// (or clause payload) itself; `fragment` is where it is written.
const keyless = (label, source, fragment) => ({ compile, Left, wire }) => {
  const result = compile(source);
  assert.ok(result instanceof Left, `Fail family (${label}): accepted`);
  const found = wire(result.value0);
  assert.equal(found.code, 'E_TYPE', `Fail family (${label}): wrong code`);
  assert.equal(found.span.start.offset, source.indexOf(fragment),
    `Fail family (${label}): wrong span`);
};
const caller = 'type E = E; fn g(h: Int -> Unit with Fail(P)): Unit = h(1); '
  + 'fn main(): Unit with Console = g(fn(n: Int) => fail(E));';

export const task5Probes = {
  'signature-fail': keyless('variable', caller.replace('P', 'a'), 'Fail(a)'),
  'keyless-fail': keyless('function', caller.replace('P', 'Int -> Int'),
    'Fail(Int -> Int)'),
  'clause-fail': keyless('clause',
    'fn main(): Int = handle 0 { fail(e: Int -> Int) => 1 };', 'Int -> Int'),
  'duplicate-scan-timing': duplicateScanTiming
};
