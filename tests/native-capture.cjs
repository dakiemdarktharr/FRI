const fs=require('node:fs');
module.exports=async function capture(app,page,output){
 if(process.env.FRI_TEST_HIDDEN!=='1')return page.screenshot({path:output});
 const base64=await app.evaluate(async({BrowserWindow},url)=>{
  const win=BrowserWindow.getAllWindows().find(w=>w.webContents.getURL()===url);
  const image=await win.webContents.capturePage(undefined,{stayHidden:true,stayAwake:true});
  return image.toPNG().toString('base64');
 },page.url());
 fs.writeFileSync(output,Buffer.from(base64,'base64'));
};
