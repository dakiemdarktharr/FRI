const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {_electron}=require('../tests/node_modules/playwright');
const [exe,profile,mode,version]=process.argv.slice(2);
(async()=>{
  const env={...process.env,FRI_TEST_MODE:'1',FRI_TEST_USER_DATA:profile};delete env.ELECTRON_RUN_AS_NODE;
  const app=await _electron.launch({executablePath:exe,args:[],env});
  try{
    const p=await app.firstWindow();await p.waitForFunction(()=>window.FRI_PREVIEW);
    assert.equal(await p.evaluate(()=>window.friDesktop.version),version);
    if(mode==='seed'){
      await p.locator('[data-menu=new]').click();await p.locator('[data-command=deadline]').click();
      await p.locator('[name=title]').fill('Installer upgrade retained this deadline');await p.locator('[name=time]').fill('23:59');
      await p.getByRole('button',{name:'Done',exact:true}).click();await p.locator('#modal').waitFor({state:'hidden'});
      await p.locator('[data-action=settings]').click();await p.locator('#text-setting').check();await p.getByRole('button',{name:'Done',exact:true}).click();
    }
    await p.evaluate(()=>FRI_PREVIEW.settled?.());
    const s=await p.evaluate(()=>FRI_PREVIEW.getState());
    const expectedFile=path.join(profile,'upgrade-expectation.json');if(mode==='seed')fs.writeFileSync(expectedFile,JSON.stringify({tasks:s.tasks,large:s.settings.large}));const expected=JSON.parse(fs.readFileSync(expectedFile,'utf8'));assert.deepEqual(s.tasks,expected.tasks);assert.equal(s.settings.large,expected.large);assert(s.tasks.some(t=>t.title==='Installer upgrade retained this deadline'));assert.equal(s.settings.large,true);
    console.log(JSON.stringify({version,mode,appointments:s.tasks.length,deadlinePreserved:true,settingsPreserved:true,origin:await p.evaluate(()=>location.origin)}));
  }finally{await app.close();}
})().catch(e=>{console.error(e);process.exit(1)});
