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

const dependencies = {
  'Sprig.Model': [],
  'Sprig.Lex': ['Sprig.Model'],
  'Sprig.Resolved': ['Sprig.Model'],
  'Sprig.Parse.Core': ['Sprig.Model', 'Sprig.Lex'],
  'Sprig.Parse.Declaration': ['Sprig.Model', 'Sprig.Lex', 'Sprig.Parse.Core'],
  'Sprig.Parse.Literal': ['Sprig.Model', 'Sprig.Parse.Core'],
  'Sprig.Parse.Pattern': ['Sprig.Model', 'Sprig.Lex', 'Sprig.Parse.Core', 'Sprig.Parse.Literal'],
  'Sprig.Parse.Expression': ['Sprig.Model', 'Sprig.Lex', 'Sprig.Parse.Core', 'Sprig.Parse.Literal', 'Sprig.Parse.Pattern'],
  'Sprig.Parse': ['Sprig.Model', 'Sprig.Lex', 'Sprig.Parse.Core', 'Sprig.Parse.Declaration', 'Sprig.Parse.Expression'],
  'Sprig.Resolve.Types': ['Sprig.Model', 'Sprig.Resolved'],
  'Sprig.Resolve.Pattern': ['Sprig.Model', 'Sprig.Resolved'],
  'Sprig.Resolve.Expression': ['Sprig.Model', 'Sprig.Resolved', 'Sprig.Resolve.Pattern'],
  'Sprig.Resolve': ['Sprig.Model', 'Sprig.Resolved', 'Sprig.Resolve.Types', 'Sprig.Resolve.Expression'],
  'Sprig.IR.Internal': ['Sprig.Model', 'Sprig.Resolved'],
  'Sprig.Check.Match': ['Sprig.Model', 'Sprig.Resolved', 'Sprig.IR.Internal'],
  'Sprig.Check.Usefulness': ['Sprig.Resolved', 'Sprig.IR.Internal'],
  'Sprig.Check.Coverage': ['Sprig.Model', 'Sprig.Resolved', 'Sprig.IR.Internal', 'Sprig.Check.Usefulness'],
  'Sprig.Check': ['Sprig.Model', 'Sprig.Resolved', 'Sprig.IR.Internal', 'Sprig.Check.Match', 'Sprig.Check.Coverage'],
  'Sprig.Go.Data': ['Sprig.Resolved'],
  'Sprig.Go.Match': ['Sprig.Resolved', 'Sprig.IR.Internal', 'Sprig.Go.Data'],
  'Sprig.Go': ['Sprig.Check', 'Sprig.Resolved', 'Sprig.IR.Internal', 'Sprig.Go.Data', 'Sprig.Go.Match'],
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
  findings.push(...files.filter(file => file.startsWith('src/Sprig/') && file.endsWith('.js')).map(file => `${file}: FFI in pure core`));
  const result = spawnSync('purs', ['graph', 'src/**/*.purs', '.spago/p/*/src/**/*.purs'], { encoding: 'utf8', maxBuffer: graphBufferBytes });
  if (result.error || result.status !== 0) findings.push(`purs graph failed: ${result.error?.message ?? result.stderr}`);
  else findings.push(...graphFindings(JSON.parse(result.stdout)));
  return findings;
};
