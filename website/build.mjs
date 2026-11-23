import {readFile,writeFile} from 'node:fs/promises';
const root=new URL('./',import.meta.url);
const read=name=>readFile(new URL(name,root),'utf8');
const [shell,css,js,logo,ocean]=await Promise.all([
  read('page.html'),read('style.css'),read('app.js'),read('assets/fri-pole.svg'),readFile(new URL('assets/ocean.webp',root))
]);
const data='data:image/webp;base64,'+ocean.toString('base64');
const html=shell.replace('/*__STYLE__*/',()=>css).replace('/*__SCRIPT__*/',()=>js)
  .replaceAll('__OCEAN__',data).replaceAll('__POLE__',logo.replace('fill="#955251"','fill="currentColor"').replace('<svg ','<svg aria-hidden="true" '));
await writeFile(new URL('../FRI-website.html',root),html);
console.log('Built FRI-website.html ('+Math.round(Buffer.byteLength(html)/1024)+' KiB), self-contained.');
