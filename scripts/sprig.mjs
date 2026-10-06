import { resolve } from 'node:path';
process.env.GOCACHE ??= resolve('.build/go-cache');
import { main } from '../output/Shell.CLI/index.js';
main();
