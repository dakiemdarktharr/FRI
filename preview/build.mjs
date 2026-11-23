import { build } from 'esbuild';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const here = path.dirname(fileURLToPath(import.meta.url));
await mkdir(path.join(here,'.build'),{recursive:true});
const bundle = await build({entryPoints:[path.join(here,'gradient.jsx')],bundle:true,minify:true,write:false,format:'iife',target:'es2022',define:{'process.env.NODE_ENV':'"production"'},legalComments:'inline'});
const calendarBundle=await build({entryPoints:[path.join(here,'calendar-source.js')],bundle:true,minify:true,write:false,format:'iife',target:'es2022',legalComments:'inline'});
const importPlan=await readFile(path.join(here,'import-plan.cjs'),'utf8');
const smartIntake=await readFile(path.join(here,'smart-intake.js'),'utf8');
const index=await readFile(path.join(here,'../index.html'),'utf8');
const domain=[...index.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].find(m=>/const FriDomain\s*=/.test(m[1]))[1]+'\nwindow.FriDomain=FriDomain;';
const planning=await readFile(path.join(here,'planning.cjs'),'utf8'),intake=await readFile(path.join(here,'intake.js'),'utf8');
const native=await readFile(path.join(here,'native.js'),'utf8');
const chrome=await readFile(path.join(here,'chrome.js'),'utf8');
let html = await readFile(path.join(here,'shell.html'),'utf8');
const css=(await readFile(path.join(here,'style.css'),'utf8'))+'\n'+(await readFile(path.join(here,'brand.css'),'utf8')),app=await readFile(path.join(here,'app.js'),'utf8');
html=html.replace('/*__CSS__*/',()=>css)
  .replace('/*__APP__*/',()=>domain+'\n'+planning+'\n'+importPlan+'\n'+calendarBundle.outputFiles[0].text+'\n'+smartIntake+'\n'+intake+'\n'+native+'\n'+app)
  .replace('/*__CHROME__*/',()=>chrome)
  .replace('/*__GRADIENT__*/',()=>bundle.outputFiles[0].text.replace(/<\/script/gi,'<\\/script'))
  .replaceAll('__DAY_IMAGE__','data:image/png;base64,'+(await readFile(path.join(here,'assets/day.png'))).toString('base64'));
const notices=await readFile(path.join(here,'THIRD-PARTY-NOTICES.txt'),'utf8');
html=html.replace('</body>',()=>`<!-- ${notices.replaceAll('--','—')} -->\n</body>`);
await writeFile(path.join(here,'../FRI-liquid-glass.html'),html);
console.log(`Built standalone FRI-liquid-glass.html (${(Buffer.byteLength(html)/1024/1024).toFixed(2)} MB)`);
