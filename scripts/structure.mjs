import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

export const filesUnder = root => readdirSync(root, { withFileTypes: true }).flatMap(entry =>
  entry.isDirectory() ? filesUnder(join(root, entry.name)) : [join(root, entry.name)]);

const dependencies = {
  'Sprig.Model': [],
  'Sprig.Lex': ['Sprig.Model'],
  'Sprig.Resolved': ['Sprig.Model'],
  'Sprig.Parse.Core': ['Sprig.Model', 'Sprig.Lex'],
  'Sprig.Parse.Expression': ['Sprig.Model', 'Sprig.Lex', 'Sprig.Parse.Core'],
  'Sprig.Parse': ['Sprig.Model', 'Sprig.Lex', 'Sprig.Parse.Core', 'Sprig.Parse.Expression'],
  'Sprig.Resolve': ['Sprig.Model', 'Sprig.Resolved'],
  'Sprig.IR.Internal': ['Sprig.Model', 'Sprig.Resolved'],
  'Sprig.Check': ['Sprig.Model', 'Sprig.Resolved', 'Sprig.IR.Internal'],
  'Sprig.Go': ['Sprig.Check', 'Sprig.Model', 'Sprig.Resolved', 'Sprig.IR.Internal'],
  'Sprig.Compiler': ['Sprig.Model', 'Sprig.Parse', 'Sprig.Resolve', 'Sprig.Check', 'Sprig.Go'],
  'Shell.CLI': ['Sprig.Compiler', 'Sprig.Model']
};

export const graphFindings = graph => Object.entries(graph).flatMap(([name, module]) => {
  if (!module.path.startsWith('src/')) return [];
  if (!(name in dependencies)) return [`unregistered module: ${name}`];
  return module.depends.flatMap(dependency => {
    if (dependency in dependencies) {
      return dependencies[name].includes(dependency) ? [] : [`${name} imports ${dependency}`];
    }
    if (name.startsWith('Sprig.') && /(^|\.)(Unsafe|Partial)(\.|$)/.test(dependency)) return [`pure module ${name} imports ${dependency}`];
    if (name.startsWith('Sprig.') && !/^(Prelude$|Data\.(Array|Either|Maybe|Int|String|Foldable|Traversable)(\.|$))/.test(dependency)) {
      return [`pure module ${name} imports ${dependency}`];
    }
    return [];
  });
});

export const textFindings = (file, source) => {
  const findings = [];
  const lines = source.split('\n').length - (source.endsWith('\n') ? 1 : 0);
  if (lines > 250) findings.push(`${file}: ${lines} lines exceeds 250`);
  if (file.endsWith('.purs')) source.split('\n').forEach((line, index) => {
    if ([...line].length > 80) findings.push(`${file}:${index + 1}: exceeds 80 columns`);
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
  findings.push(...files.filter(file => file.startsWith('src/Sprig/') && file.endsWith('.js')).map(file => `${file}: FFI in pure core`));
  const result = spawnSync('purs', ['graph', 'src/**/*.purs', '.spago/p/*/src/**/*.purs'], { encoding: 'utf8', maxBuffer: 4 * 1024 * 1024 });
  if (result.error || result.status !== 0) findings.push(`purs graph failed: ${result.error?.message ?? result.stderr}`);
  else findings.push(...graphFindings(JSON.parse(result.stdout)));
  return findings;
};
