// Spago 1.0.4 has no cache override on macOS. Scope this adapter to its process.
import os from 'node:os';
import { syncBuiltinESMExports } from 'node:module';
import { resolve } from 'node:path';
os.homedir = () => resolve('.build/home');
syncBuiltinESMExports();
// Make env-paths use the mocked home even with host-specific cache settings.
for (const key of ['XDG_CACHE_HOME', 'APPDATA', 'LOCALAPPDATA']) delete process.env[key];
