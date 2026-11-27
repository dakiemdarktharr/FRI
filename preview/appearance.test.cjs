const {chromium,webkit}=require('../tests/node_modules/playwright');
const AxeBuilder=require('../tests/node_modules/@axe-core/playwright').default;
const {test}=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
function ratio(a,b){const lum=c=>{const rgb=c.match(/[\d.]+/g).slice(0,3).map(Number).map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722};const x=lum(a),y=lum(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05)}
test('light and dark calendar keep text, controls and Vietnamese legible',async()=>{
 const browser=await (process.env.FRI_BROWSER==='webkit'?webkit:chromium).launch();const context=await browser.newContext({viewport:{width:1440,height:1000},reducedMotion:'reduce'});const page=await context.newPage();
 const out=path.resolve(__dirname,'../test-results/dark-type');fs.mkdirSync(out,{recursive:true});const findings=[];
 try{
  await page.goto(require('node:url').pathToFileURL(path.resolve(__dirname,'../FRI-liquid-glass.html')).href);
  await page.waitForFunction(()=>window.FRI_COMMAND);await page.evaluate(()=>document.fonts.ready);
  for(const theme of ['light','dark']){
   await page.evaluate(()=>FRI_COMMAND('settings'));await page.locator('#theme-mode').selectOption(theme);await page.getByRole('button',{name:'Done',exact:true}).click();
   await page.evaluate(()=>FRI_COMMAND('day'));
   const control=await page.locator('.feed-check').first().evaluate(e=>{const s=getComputedStyle(e);return {edge:s.borderTopColor,bg:s.backgroundColor}});
   assert(ratio(control.edge,control.bg)>=3,'completion control boundary is visible');
   for(const view of ['day','week','month','year','schedule','settings','insights','intake','widgets']){
    await page.evaluate(v=>FRI_COMMAND(v),view);await page.waitForTimeout(100);
    if(view==='schedule')await page.locator('[name=title]').fill('Lịch hẹn · Tiếng Việt đầy đủ: Ắ Ỗ Ữ Ỵ · Nguyễn');
    if(view==='month'){
     await page.locator('.day-cell.today').hover();
     const selected=await page.locator('.day-cell.today').evaluate(e=>{const s=getComputedStyle(e);return {text:s.color,bg:s.backgroundColor}});
     assert(ratio(selected.text,selected.bg)>=4.5,'today remains readable while hovered');
     await page.mouse.move(0,0);
    }
    await page.evaluate(()=>document.fonts.ready);
    const results=await new AxeBuilder({page}).withRules(['color-contrast']).analyze();
    findings.push({theme,view,violations:results.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary,html:n.html}))}))});
    await page.screenshot({path:path.join(out,`${theme}-${view}.png`)});
    await page.evaluate(()=>document.querySelector('#modal')?.close());
   }
   await page.evaluate(()=>FRI_COMMAND('day'));
   for(const width of [375,768,1440]){
    await page.setViewportSize({width,height:1000});await page.screenshot({path:path.join(out,`${theme}-feed-${width}.png`)});
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'page fits viewport');
   }
   await page.setViewportSize({width:1440,height:1000});
  }
  assert.equal(await page.evaluate(()=>getComputedStyle(document.body).fontFamily.split(',')[0]),'BeVietnamPro');
  assert(await page.evaluate(()=>document.fonts.check('600 18px BeVietnamPro','Tiếng Việt Ắ Ỗ Ữ Ỵ đ ơ ư')));
  fs.writeFileSync(path.join(out,'contrast.json'),JSON.stringify(findings,null,2));
  assert.deepEqual(findings.filter(f=>f.violations.length),[],'visible text meets WCAG AA contrast');
 }finally{await browser.close()}
});
