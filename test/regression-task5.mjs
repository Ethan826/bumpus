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

export const task5Probes = {
  'duplicate-scan-timing': duplicateScanTiming
};
