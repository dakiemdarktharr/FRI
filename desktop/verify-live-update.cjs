// Opt-in release verification against an isolated, already-installed old test build.
// The caller owns installation/cleanup. No production profile is opened.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {_electron}=require('../tests/node_modules/playwright');
const [exe,profile,expected]=process.argv.slice(2);
if(!exe||!profile||!expected)throw Error('Usage: node verify-live-update.cjs <installed-test-exe> <test-profile> <expected-version>');
const allowed=path.resolve('D:/FRI-work')+path.sep;
for(const target of [exe,profile])assert(path.resolve(target).startsWith(allowed),'Use isolated FRI-work test paths.');
(async()=>{
  const env={...process.env,FRI_TEST_MODE:'1',FRI_TEST_USER_DATA:profile};delete env.ELECTRON_RUN_AS_NODE;
  const app=await _electron.launch({executablePath:exe,args:[],env});
  try{
    const p=await app.firstWindow();await p.locator('.task').first().waitFor();
    await app.evaluate(async({app,dialog})=>{
      const updater=process.mainModule.require(app.getAppPath()+'/node_modules/electron-updater').autoUpdater;
      global.friLiveUpdate={state:'checking'};
      // Exercise the real app download handler, choosing Later at its install prompt.
      dialog.showMessageBox=async(_win,options)=>{
        if(options.buttons?.[0]==='Download update')return {response:0};
        if(options.buttons?.[0]==='Restart and install'){global.friLiveUpdate.ready=true;return {response:1};}
        throw Error(`Unexpected update dialog: ${options.message}`);
      };
      updater.once('error',error=>{global.friLiveUpdate={state:'error',message:error.message}});
      updater.once('update-downloaded',info=>{global.friLiveUpdate={state:'downloaded',version:info.version,file:info.downloadedFile}});
      global.friVerifiedUpdater=updater;
      await updater.checkForUpdates();
    });
    let receipt;
    for(let i=0;i<300;i++){
      receipt=await app.evaluate(()=>global.friLiveUpdate);
      if(receipt.state==='error')throw Error(receipt.message);
      if(receipt.state==='downloaded'&&receipt.ready)break;
      await new Promise(resolve=>setTimeout(resolve,1000));
    }
    assert.equal(receipt.state,'downloaded');assert.equal(receipt.ready,true);assert.equal(receipt.version,expected);
    fs.writeFileSync(path.join(path.dirname(profile),'live-update-receipt.json'),JSON.stringify(receipt,null,2));
    console.log(JSON.stringify({state:receipt.state,version:receipt.version,checksumVerifiedByUpdater:true}));
    // Same NSIS update path as the app, with unattended installation for this test.
    const exited=new Promise(resolve=>app.process().once('exit',resolve));
    await app.evaluate(()=>global.friVerifiedUpdater.quitAndInstall(true,false)).catch(error=>{
      if(!/closed|destroyed/i.test(error.message))throw error;
    });
    await exited;
  }finally{await app.close().catch(()=>{});}
})().catch(e=>{console.error(e);process.exit(1)});
