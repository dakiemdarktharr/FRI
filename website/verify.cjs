const assert=require('node:assert/strict');
const path=require('node:path');
const fs=require('node:fs/promises');
const {pathToFileURL}=require('node:url');
const {chromium,webkit}=require('../tests/node_modules/playwright');
const AxeBuilder=require('../tests/node_modules/@axe-core/playwright').default;
const url=pathToFileURL(path.resolve(__dirname,'../FRI-website.html')).href;
const output=path.resolve(__dirname,'../test-results/website');
const results=[];
async function check(name,fn){await fn();results.push(name);console.log('PASS '+name)}
(async()=>{
 await fs.mkdir(output,{recursive:true});
 for(const [engine,type] of [['chromium',chromium],['webkit',webkit]]){
  const browser=await type.launch({headless:true});
  try {
   const context=await browser.newContext({viewport:{width:1440,height:1000}});
   const page=await context.newPage();
   const errors=[];page.on('pageerror',e=>errors.push(e.message));
   await page.addInitScript(()=>{Object.defineProperty(navigator,'platform',{get:()=> 'Win32'});Object.defineProperty(navigator,'userAgentData',{get:()=>undefined})});
   await page.goto(url);
   await check(engine+' / loading, black, first notification, popup, calendar, 1300ms overload',async()=>{
    await page.waitForFunction(()=>window.FRI_WEBSITE?.evidence.events.some(e=>e.name==='spam-start'));
    if(engine==='chromium'){await page.waitForTimeout(900);await page.screenshot({path:path.join(output,'intro-overload.png')})}
    await page.locator('#quiet').waitFor({state:'visible'});
    const events=await page.evaluate(()=>FRI_WEBSITE.evidence.events);
    assert.deepEqual(events.map(x=>x.name),['loading','black','notification','popup','calendar','spam-start','spam-end','question']);
    const duration=events.find(x=>x.name==='spam-end').time-events.find(x=>x.name==='spam-start').time;
    assert.ok(duration>=1280&&duration<1600,'Spam lasted '+duration+'ms');
    assert.equal(await page.locator('#quiet button').count(),1);
    assert.ok(await page.locator('.noise-card').count()>40);
    assert.equal(await page.evaluate(()=>document.activeElement.id),'enter');
    if(engine==='chromium'){await page.waitForTimeout(700);await page.screenshot({path:path.join(output,'intro-question.png')})}
   });
   await page.locator('#enter').click();
   await page.locator('#intro').waitFor({state:'hidden'});
   await check(engine+' / landing and exact release download',async()=>{
    assert.equal(await page.locator('h1').textContent(),'Fri.');
    assert.match(await page.locator('.download').first().getAttribute('href'),/FRI-0\.2\.0-win-x64\.exe$/);
    assert.equal(await page.locator('.download-label').first().textContent(),'Download for Windows');
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    if(engine==='chromium'){await page.screenshot({path:path.join(output,'landing-desktop.png')});await page.screenshot({path:path.join(output,'website-full.png'),fullPage:true})}
   });
   await check(engine+' / ocean animation and pause control',async()=>{
    const state=await page.evaluate(()=>FRI_WEBSITE.evidence.ocean);
    assert.ok(['webgl','static-photo'].includes(state));
    if(state==='webgl'){
     const before=await page.evaluate(()=>FRI_WEBSITE.evidence.seaFrames);
     await page.waitForTimeout(350);
     assert.ok(await page.evaluate(()=>FRI_WEBSITE.evidence.seaFrames)>before);
    }
    await page.locator('.sea-control').click();
    const stopped=await page.evaluate(()=>FRI_WEBSITE.evidence.seaFrames);
    await page.waitForTimeout(250);
    assert.equal(await page.evaluate(()=>FRI_WEBSITE.evidence.seaFrames),stopped);
    await page.locator('.sea-control').click();
   });
   await check(engine+' / staged demo chapters, pause, play, replay',async()=>{
    await page.locator('[data-step="0"]').click();
    await page.waitForFunction(()=>document.querySelector('#live-app .demo-field')?.textContent.includes('Coffee'));
    await page.locator('[data-step="1"]').click();
    assert.match(await page.locator('#live-app .demo-form').textContent(),/When’s coffee/);
    await page.locator('[data-step="2"]').click();
    assert.equal(await page.locator('#live-app .new-task').count(),1);
    await page.locator('#pause-demo').click();
    assert.equal(await page.locator('#pause-demo').getAttribute('aria-label'),'Play demo');
    const before=await page.evaluate(()=>FRI_WEBSITE.evidence.demoFrames);await page.waitForTimeout(300);
    assert.equal(await page.evaluate(()=>FRI_WEBSITE.evidence.demoFrames),before);
    if(engine==='chromium')await page.locator('#demo').screenshot({path:path.join(output,'demo-desktop.png')});
    await page.locator('#pause-demo').click();await page.locator('#replay-demo').click();
    assert.match(await page.locator('#live-app .demo-form').textContent(),/What’s the plan/);
   });
   await check(engine+' / navigation dialogs and keyboard close',async()=>{
    await page.locator('[data-dialog="pricing"]').click();
    assert.match(await page.locator('#info-dialog').textContent(),/Pricing is still taking shape/);
    await page.keyboard.press('Escape');assert.equal(await page.locator('#info-dialog').isVisible(),false);
    await page.locator('[data-dialog="signup"]').click();await page.locator('#choose-download').click();
    assert.equal(await page.locator('.download-option').count(),3);await page.locator('.dialog-close').click();
    await page.locator('[data-demo-jump="1"]').click();
    assert.equal(await page.locator('[data-step="1"]').getAttribute('aria-pressed'),'true');
   });
   await check(engine+' / no script errors',async()=>assert.deepEqual(errors,[]));
   if(engine==='chromium'){
    const a11y=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa']).analyze();
    await fs.writeFile(path.join(output,'accessibility.json'),JSON.stringify(a11y.violations,null,2));
    console.log('Accessibility violations:',a11y.violations.map(v=>v.id+':'+v.nodes.length).join(', ')||'none');
    assert.equal(a11y.violations.length,0,'Axe WCAG A/AA checks must pass');
   }
   const mobile=await browser.newPage({viewport:{width:390,height:844},reducedMotion:'reduce',isMobile:true,hasTouch:true});
   await mobile.addInitScript(()=>{Object.defineProperty(navigator,'platform',{get:()=> 'iPhone'});Object.defineProperty(navigator,'userAgentData',{get:()=>undefined})});
   await mobile.goto(url);await mobile.locator('#skip-intro').click();await mobile.locator('#intro').waitFor({state:'hidden'});
   await check(engine+' / mobile layout, reduced motion, download selection',async()=>{
    assert.equal(await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    assert.equal(await mobile.locator('#pause-demo').getAttribute('aria-label'),'Play demo');
    assert.equal(await mobile.locator('.sea-control').getAttribute('aria-label'),'Play ocean motion');
    await mobile.locator('.download').first().click();
    assert.equal(await mobile.locator('.download-option').count(),3);
    await mobile.locator('.dialog-close').click();
    if(engine==='chromium'){await mobile.screenshot({path:path.join(output,'landing-mobile.png')});await mobile.screenshot({path:path.join(output,'website-mobile-full.png'),fullPage:true})}
    await mobile.locator('[data-step="1"]').click();assert.match(await mobile.locator('#live-app .demo-form').textContent(),/When’s coffee/);
    const heading=await mobile.locator('#demo-title').boundingBox();
    const controls=await mobile.locator('.heading-controls').boundingBox();
    assert.ok(controls.y>=heading.y+heading.height,'Demo controls do not overlap the heading');
    await mobile.setViewportSize({width:320,height:740});
    assert.equal(await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
   });
   await mobile.close();
   const mac=await browser.newPage({reducedMotion:'reduce'});
   await mac.addInitScript(()=>{Object.defineProperty(navigator,'platform',{get:()=> 'MacIntel'});Object.defineProperty(navigator,'userAgentData',{get:()=>undefined})});
   await mac.goto(url);await mac.keyboard.press('Escape');
   await check(engine+' / macOS architecture is chosen, not inferred',async()=>{
    await mac.locator('#intro').waitFor({state:'hidden'});
    assert.equal(await mac.locator('.download-label').first().textContent(),'Download for macOS');
    await mac.locator('.download').first().click();
    assert.match(await mac.locator('.download-option').nth(1).getAttribute('href'),/mac-arm64\.dmg$/);
    assert.match(await mac.locator('.download-option').nth(2).getAttribute('href'),/mac-x64\.dmg$/);
   });
   await mac.close();
   await check(engine+' / replay intro and Escape skip',async()=>{
    await page.locator('#replay-intro').click();
    assert.equal(await page.locator('#intro').isVisible(),true);
    await page.keyboard.press('Escape');
    await page.locator('#intro').waitFor({state:'hidden'});
    assert.equal(await page.evaluate(()=>document.querySelector('#site').inert),false);
   });
   await page.close();
  } finally {await browser.close()}
 }
 await fs.writeFile(path.join(output,'verification.json'),JSON.stringify({date:'2026-11-23',checks:results},null,2));
 console.log(results.length+' checks passed.');
})().catch(e=>{console.error(e);process.exitCode=1});
