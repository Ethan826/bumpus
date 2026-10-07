import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

export const filesUnder = root => readdirSync(root, { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? filesUnder(join(root, entry.name)) : [join(root, entry.name)]);

const maximumFileLines = 250;
const maximumPureScriptColumns = 80;
const bytesPerKibibyte = 1024;
const graphBufferMebibytes = 4;
const graphBufferBytes = graphBufferMebibytes * bytesPerKibibyte ** 2;

export const layers = ['Domain', 'Features', 'Format', 'Runtime', 'Program'];
const pureLayers = ['Domain', 'Features', 'Format'];
// Control.Monad.Rec.Class supplies tailRecM, the only stack-safe loop for
// long inputs (BACKLOG E002); the rest of Control stays out of pure layers.
const coreLibraries = /^(Prelude$|Control\.Monad\.Rec\.Class$|Data\.(Array|Either|Maybe|Int|String|Foldable|Traversable)(\.|$))/;
const partialModules = /(^|\.)(Unsafe|Partial)(\.|$)/;
const irModule = 'Domain.IR.Internal';
const irImporters = /^(Features\.Check|Format\.Go)(\.|$)/;
// Commands run over capability ports only, so tests can pass fake hosts.
const portCommands = ['Program.Command'];
const hostEffects = /^(Effect|Runtime)(\.|$)/;

export const layerOf = moduleName => moduleName.split('.')[0];

const projectFinding = (name, dependency) => {
  const own = layers.indexOf(layerOf(name));
  const target = layers.indexOf(layerOf(dependency));
  if (target > own) return [`${name} (${layerOf(name)}) imports ${dependency} (${layerOf(dependency)})`];
  if (dependency === irModule && !irImporters.test(name)) return [`${name} imports ${dependency}`];
  return [];
};

const libraryFinding = (name, dependency) => {
  if (!pureLayers.includes(layerOf(name))) return [];
  if (partialModules.test(dependency) || !coreLibraries.test(dependency)) return [`pure module ${name} imports ${dependency}`];
  return [];
};

const commandFinding = (name, dependency) =>
  portCommands.includes(name) && hostEffects.test(dependency) ? [`port command ${name} imports ${dependency}`] : [];

export const graphFindings = graph => Object.entries(graph).flatMap(([name, module]) => {
  if (!module.path.startsWith('src/')) return [];
  if (!layers.includes(layerOf(name))) return [`unlayered module: ${name}`];
  return module.depends.flatMap(dependency => [...commandFinding(name, dependency),
    ...(layers.includes(layerOf(dependency)) ? projectFinding(name, dependency) : libraryFinding(name, dependency))]);
});

export const textFindings = (file, source) => {
  const findings = [];
  const lines = source.split('\n').length - (source.endsWith('\n') ? 1 : 0);
  if (lines > maximumFileLines) findings.push(`${file}: ${lines} lines exceeds ${maximumFileLines}`);
  if (file.endsWith('.purs')) source.split('\n').forEach((line, index) => {
    if ([...line].length > maximumPureScriptColumns) findings.push(`${file}:${index + 1}: exceeds ${maximumPureScriptColumns} columns`);
  });
  if (!source.endsWith('\n')) findings.push(`${file}: missing final newline`);
  if (file.endsWith('.purs') && /\b(unsafe\w*|Partial|fromJust)\b/.test(source)) findings.push(`${file}: partial escape`);
  if (/\.(skip|only|todo)\s*\(|@ts-(ignore|nocheck|expect-error)|eslint[-]disable/.test(source)) findings.push(`${file}: disabled gate or test`);
  return findings;
};

export const checkStructure = async () => {
  const { check } = await import('../output/Style.Check/index.js');
  const files = ['src', 'test', 'scripts', 'tools/style/src'].flatMap(filesUnder).filter(file => /\.(purs|mjs|js)$/.test(file));
  const findings = files.flatMap(file => textFindings(file, readFileSync(file, 'utf8')));
  findings.push(...files.filter(file => file.endsWith('.purs')).flatMap(file => check(readFileSync(file, 'utf8')).map(message => `${file}: ${message}`)));
  findings.push(...files.filter(file => file.startsWith('src/') && !file.startsWith('src/Runtime/') && file.endsWith('.js')).map(file => `${file}: FFI outside Runtime`));
  const result = spawnSync('purs', ['graph', 'src/**/*.purs', '.spago/p/*/src/**/*.purs'], { encoding: 'utf8', maxBuffer: graphBufferBytes });
  if (result.error || result.status !== 0) findings.push(`purs graph failed: ${result.error?.message ?? result.stderr}`);
  else findings.push(...graphFindings(JSON.parse(result.stdout)));
  return findings;
};
