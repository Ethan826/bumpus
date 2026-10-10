// Seeded choices for the FX001 program generator: the LCG of
// test/coverage-oracle.mjs behind a few named operations, started from a
// mixed seed so that nearby seeds give unrelated programs.
import { choose, generator } from './coverage-oracle.mjs';

const mix = seed => {
  let x = seed | 0;
  x = Math.imul(x ^ (x >>> 16), 0x45d9f3b);
  x = Math.imul(x ^ (x >>> 16), 0x45d9f3b);
  return x ^ (x >>> 16);
};

export const rng = seed => {
  const next = generator(mix(seed));
  next();
  const int = count => choose(next, count);
  return {
    int,
    // A small literal, negatives included.
    number: () => int(14) - 3,
    pick: items => items[int(items.length)],
    chance: percent => int(100) < percent,
    shuffle: items => {
      const result = [...items];
      for (let index = result.length - 1; index > 0; index--) {
        const other = int(index + 1);
        [result[index], result[other]] = [result[other], result[index]];
      }
      return result;
    }
  };
};
