// Original vector marks, rendered reproducibly for native launchers and RN.
const fs=require('node:fs'),path=require('node:path');
const {chromium}=require('../tests/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch();
 try{
  const page=await browser.newPage({viewport:{width:512,height:512},deviceScaleFactor:1});
  const mark=fs.readFileSync(path.join(__dirname,'fri-mark.svg'),'utf8');
  const mobile=path.join(__dirname,'../mobile/assets');fs.mkdirSync(mobile,{recursive:true});
  const resources=path.join(__dirname,'../desktop/resources');fs.mkdirSync(resources,{recursive:true});
  const render=async(svg,size=512)=>{await page.setViewportSize({width:size,height:size});await page.setContent('<style>body{margin:0;background:transparent}svg{display:block;width:100%;height:100%}</style>'+svg);return page.screenshot({omitBackground:true})};
  const icon='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" rx="116" fill="#087F8C"/><g transform="translate(40 36) scale(6.7)" fill="#F4F7FA">'+mark.match(/<path[\s\S]*<\/svg>/)[0].replace('</svg>','')+'</g></svg>';
  const png=await render(icon);fs.writeFileSync(path.join(resources,'icon.png'),png);fs.writeFileSync(path.join(mobile,'icon.png'),png);
  const small=await render(icon,256),header=Buffer.alloc(22);header.writeUInt16LE(1,2);header.writeUInt16LE(1,4);header.writeUInt16LE(1,10);header.writeUInt16LE(32,12);header.writeUInt32LE(small.length,14);header.writeUInt32LE(22,18);fs.writeFileSync(path.join(resources,'icon.ico'),Buffer.concat([header,small]));
  fs.writeFileSync(path.join(mobile,'fri-symbol.png'),await render(mark.replace('currentColor','#087F8C'),192));
  fs.writeFileSync(path.join(mobile,'first-plan.png'),await render(fs.readFileSync(path.join(__dirname,'first-plan.svg'),'utf8'),480));
  for(const [name,d] of Object.entries(require('./symbols.json'))){fs.writeFileSync(path.join(mobile,'symbol-'+name+'.png'),await render('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#172B3A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="'+d+'"/></svg>',72));}
  console.log('Rendered Fri naive identity for Windows and Android.');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
