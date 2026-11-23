'use strict';
// Development launcher: build the shared UI, prepare CSP, then run native Day.
const {spawnSync}=require('node:child_process');
const path=require('node:path');
const root=__dirname;
try{require.resolve('./preview/node_modules/esbuild');require.resolve('./desktop/node_modules/electron')}catch{
 console.error('Install dependencies first: npm --prefix preview ci && npm --prefix desktop ci');process.exit(1);
}
const env={...process.env};delete env.ELECTRON_RUN_AS_NODE;
for(const file of ['preview/build.mjs','desktop/prepare.cjs','desktop/node_modules/electron/cli.js']){
 const args=[path.join(root,file)];if(file.includes('electron/'))args.push(path.join(root,'desktop'));
 const run=spawnSync(process.execPath,args,{cwd:root,env,stdio:'inherit'});
 if(run.error){console.error('Could not start FRI:',run.error.message);process.exit(1)}
 if(run.status!==0)process.exit(run.status||1);
}
