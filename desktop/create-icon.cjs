// Generate the product wordmark icon from source, keeping the asset reproducible.
const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('../tests/node_modules/playwright');
(async()=>{
  const browser=await chromium.launch();
  const page=await browser.newPage({viewport:{width:512,height:512},deviceScaleFactor:1});
  await page.setContent('<style>body{margin:0;background:transparent}svg{display:block}</style><svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><rect x="8" y="8" width="496" height="496" rx="118" fill="#171717" stroke="#777" stroke-width="2"/><text x="79" y="349" fill="white" font-family="Segoe UI,Arial,sans-serif" font-size="300" font-weight="650" letter-spacing="-22">fri.</text></svg>');
  const resources=path.join(__dirname,'resources');fs.mkdirSync(resources,{recursive:true});
  await page.screenshot({path:path.join(resources,'icon.png'),omitBackground:true});
  await page.setViewportSize({width:256,height:256});await page.addStyleTag({content:'svg{width:256px;height:256px}'});
  const png=await page.screenshot({omitBackground:true});
  const header=Buffer.alloc(22);header.writeUInt16LE(1,2);header.writeUInt16LE(1,4);header.writeUInt16LE(1,10);header.writeUInt16LE(32,12);header.writeUInt32LE(png.length,14);header.writeUInt32LE(22,18);
  fs.writeFileSync(path.join(resources,'icon.ico'),Buffer.concat([header,png]));
  await browser.close();
})();
