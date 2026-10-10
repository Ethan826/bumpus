// Harvest hook for scripts/differential.mjs: loaded with
// `--import` into every test process, it appends each source that
// Format.Parse's `parse` receives to $WAXWING_HARVEST, one JSON string per
// line. Only that file's own copy of `parse` is instrumented; compiler
// output on disk is never changed.
import { appendFileSync } from 'node:fs';
import { registerHooks } from 'node:module';

const target = process.env.WAXWING_HARVEST;
const entry = 'var parse = function (source) {';

const record = source => {
  if (typeof source === 'string') {
    appendFileSync(target, `${JSON.stringify(source)}\n`);
  }
};

const instrumented = text => {
  if (!text.includes(entry)) {
    throw new Error('differential-hook: Format.Parse no longer defines '
      + '`parse` as expected; update the hook');
  }
  return text.replace(entry,
    `${entry}\n    globalThis.waxwingHarvest(source);`);
};

const load = (url, context, nextLoad) => {
  const loaded = nextLoad(url, context);
  if (!url.endsWith('/output/Format.Parse/index.js')) return loaded;
  return { ...loaded, source: instrumented(String(loaded.source)) };
};

if (target !== undefined) {
  globalThis.waxwingHarvest = record;
  registerHooks({ load });
}
