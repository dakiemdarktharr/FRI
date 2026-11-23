import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';
const root=new URL('./',import.meta.url);
const read=name=>readFile(new URL(name,root),'utf8');
const [shell,css,js,logo,refine,motion,surf]=await Promise.all([
  read('page.html'),read('style.css'),read('app.js'),read('assets/fri-pole.svg'),read('refinement.css'),read('motion.js'),readFile(new URL('assets/ocean-loop.mp4',root))
]);
const poster='data:image/jpeg;base64,'+(await readFile(new URL('assets/ocean-poster.jpg',root))).toString('base64');
const html=shell.replace('/*__STYLE__*/',()=>css+'\n'+refine).replace('/*__SCRIPT__*/',()=>js).replace('/*__MOTION__*/',()=>motion)
  .replaceAll('__POSTER__',poster)
  .replaceAll('__POLE__',logo.replace('fill="#955251"','fill="currentColor"').replace('<svg ','<svg aria-hidden="true" '));
await writeFile(new URL('../FRI-website.html',root),html.replace('__SURF__','data:video/mp4;base64,'+surf.toString('base64')));
await mkdir(new URL('public/pricing/',root),{recursive:true});
await mkdir(new URL('public/assets/',root),{recursive:true});
await copyFile(new URL('assets/ocean-loop.mp4',root),new URL('public/assets/ocean-loop.mp4',root));
await writeFile(new URL('public/index.html',root),html.replace('__SURF__','/assets/ocean-loop.mp4'));
await writeFile(new URL('public/pricing/index.html',root),html.replace('__SURF__','/assets/ocean-loop.mp4'));
console.log('Built FRI-website.html ('+Math.round((Buffer.byteLength(html)+surf.length*4/3)/1024)+' KiB), self-contained.');
