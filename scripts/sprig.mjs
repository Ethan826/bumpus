import { resolve } from 'node:path';
process.env.GOCACHE ??= resolve('.build/go-cache');
import { main } from '../output/Program.Main/index.js';
main();
