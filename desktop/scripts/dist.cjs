'use strict';
const {spawnSync} = require('node:child_process');
const path = require('node:path');
const script = process.platform === 'darwin' ? path.join(__dirname,'build-mac.cjs') : require.resolve('electron-builder/cli.js');
if (process.platform !== 'darwin') require('../prepare.cjs');
const args = process.platform === 'darwin' ? [] : ['--publish','never'];
const result = spawnSync(process.execPath, [script, ...args], {stdio:'inherit', cwd:path.resolve(__dirname,'..')});
if (result.error) console.error(result.error.message);
process.exitCode = result.status ?? 1;
