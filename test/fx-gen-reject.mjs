// Generated programs the compiler must reject (strict `defer`, spec §2):
// a `defer` that fails directly, through a called function, through a
// callback parameter with an ambient row, and through one with a named
// row. Each gives { source, text, message }: E_EFFECT with this exact
// message, spanning the `defer` item `text`.
import { prelude } from './fx-programs.mjs';
import { rng } from './fx-gen-rng.mjs';

const payloads = {
  Err: n => `Err1(${n})`, Oops: n => `Oops(${n})`
};
const bad = { Err: 'badErr', Oops: 'badOops' };
const helpers = 'fn badErr(n: Int): Unit with Fail(Err) = fail(Err1(n)); '
  + 'fn badOops(n: Int): Unit with Fail(Oops) = fail(Oops(n)); ';

// Filler statements; `quiet` ones perform nothing (a callback's function
// has no Console in its signature).
const surround = (r, defer, quiet) => {
  const statement = () => (quiet ? r.pick([`let v${r.int(9)} = ${r.number()};`, '();'])
    : `print(${r.number()});`);
  const fill = () => Array.from({ length: r.int(3) }, statement).join(' ');
  return `${fill()} ${defer}; ${fill()}`;
};

// kind 0: directly, 1: through a function, 2: ambient callback, 3: named.
export const rejection = (seed, index) => {
  const r = rng(seed);
  const kind = index % 4;
  const family = r.pick(['Err', 'Oops']);
  const n = r.number();
  const row = `Fail(${family})`;
  const allowed = r.chance(50) ? ` with ${row} + Console` : ' with Console';
  if (kind < 2) {
    const text = kind === 0 ? `defer fail(${payloads[family](n)})`
      : `defer ${bad[family]}(${n})`;
    const source = `${prelude} ${helpers}fn work(): Unit${allowed} = `
      + `{ ${surround(r, text, false)} }; fn main(): Unit = ();`;
    return { source, text, message: `defer must not fail, but it performs ${row}` };
  }
  const name = r.pick(['release', 'cleanup', 'done']);
  const spread = kind === 3 ? r.pick(['e', 'r', 'rest']) : null;
  const type = spread ? `Unit -> Unit with ...${spread}` : 'Unit -> Unit';
  const text = `defer ${name}(())`;
  const source = `${prelude} fn bracket(${name}: ${type}): Unit`
    + `${spread ? ` with ...${spread}` : ''} = { ${surround(r, text, true)} }; `
    + 'fn main(): Unit = ();';
  return { source, text, message: 'defer must not fail, but it may perform '
    + `any effect of ${spread ? `...${spread}` : '...'}` };
};
