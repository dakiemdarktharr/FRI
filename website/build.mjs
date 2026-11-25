import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';
import {typography} from '../brand/typography.mjs';
const typeCss=await typography();
const root=new URL('./',import.meta.url);
const read=name=>readFile(new URL(name,root),'utf8');
const [shell,css,js,logo,refine,motion,surf]=await Promise.all([
  read('page.html'),read('style.css'),read('app.js'),read('assets/fri-pole.svg'),read('refinement.css'),read('motion.js'),readFile(new URL('assets/ocean-loop.mp4',root))
]);
const widgetVideo=await readFile(new URL('assets/widget-walkthrough.mp4',root));
const widgetWebm=await readFile(new URL('assets/widget-walkthrough.webm',root));
const widgetPoster='data:image/jpeg;base64,'+(await readFile(new URL('assets/widget-poster.jpg',root))).toString('base64');
const poster='data:image/jpeg;base64,'+(await readFile(new URL('assets/ocean-poster.jpg',root))).toString('base64');
const cloudCss=await read('cloud.css');
const positioningCss=await read('positioning.css'),productStories=await read('product-stories.html');
const storiesCss=await read('stories.css'),storiesJs=await read('stories.js');
const html=shell.replace('<!--__PRODUCT_STORIES__-->',()=>productStories).replace('/*__STYLE__*/',()=>css+'\n'+refine+'\n'+storiesCss+'\n'+cloudCss+'\n'+positioningCss+'\n'+typeCss).replace('/*__SCRIPT__*/',()=>js).replace('/*__MOTION__*/',()=>motion).replace('/*__STORIES__*/',()=>storiesJs)
  .replaceAll('__POSTER__',poster).replaceAll('__WIDGET_POSTER__',widgetPoster)
  .replaceAll('__POLE__',logo.replace('fill="#955251"','fill="currentColor"').replace('<svg ','<svg aria-hidden="true" '));
await writeFile(new URL('../FRI-website.html',root),html.replace('__SURF__','data:video/mp4;base64,'+surf.toString('base64')).replace('__WIDGET_VIDEO__','data:video/mp4;base64,'+widgetVideo.toString('base64')).replace('__WIDGET_WEBM__','data:video/webm;base64,'+widgetWebm.toString('base64')));
await mkdir(new URL('public/pricing/',root),{recursive:true});
await mkdir(new URL('public/assets/',root),{recursive:true});
await copyFile(new URL('assets/ocean-loop.mp4',root),new URL('public/assets/ocean-loop.mp4',root));
await copyFile(new URL('assets/widget-walkthrough.mp4',root),new URL('public/assets/widget-walkthrough.mp4',root));
await copyFile(new URL('assets/widget-walkthrough.webm',root),new URL('public/assets/widget-walkthrough.webm',root));
const served=html.replace('__SURF__','/assets/ocean-loop.mp4').replace('__WIDGET_VIDEO__','/assets/widget-walkthrough.mp4').replace('__WIDGET_WEBM__','/assets/widget-walkthrough.webm');
await writeFile(new URL('public/index.html',root),served);
await writeFile(new URL('public/pricing/index.html',root),served);
console.log('Built FRI-website.html ('+Math.round((Buffer.byteLength(html)+surf.length*4/3)/1024)+' KiB), self-contained.');
