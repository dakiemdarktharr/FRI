import { build } from 'esbuild';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const here = path.dirname(fileURLToPath(import.meta.url));
await mkdir(path.join(here,'.build'),{recursive:true});
const bundle = await build({entryPoints:[path.join(here,'gradient.jsx')],bundle:true,minify:true,write:false,format:'iife',target:'es2022',define:{'process.env.NODE_ENV':'"production"'},legalComments:'inline'});
let html = await readFile(path.join(here,'shell.html'),'utf8');
const css=await readFile(path.join(here,'style.css'),'utf8'),app=await readFile(path.join(here,'app.js'),'utf8');
html=html.replace('/*__CSS__*/',()=>css)
  .replace('/*__APP__*/',()=>app)
  .replace('/*__GRADIENT__*/',()=>bundle.outputFiles[0].text.replace(/<\/script/gi,'<\\/script'))
  .replaceAll('__DAY_IMAGE__','data:image/png;base64,'+(await readFile(path.join(here,'assets/day.png'))).toString('base64'));
const notices=await readFile(path.join(here,'THIRD-PARTY-NOTICES.txt'),'utf8');
html=html.replace('</body>',()=>`<!-- ${notices.replaceAll('--','—')} -->\n</body>`);
await writeFile(path.join(here,'../FRI-liquid-glass.html'),html);
console.log(`Built standalone FRI-liquid-glass.html (${(Buffer.byteLength(html)/1024/1024).toFixed(2)} MB)`);
