const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {chromium,webkit}=require('../tests/node_modules/playwright');
const output='test-results/positioning';fs.mkdirSync(output,{recursive:true});
(async()=>{for(const [name,engine] of [['chromium',chromium],['webkit',webkit]].filter(([n])=>!process.env.FRI_BROWSER||process.env.FRI_BROWSER===n)){
 const browser=await engine.launch();try{
  const p=await browser.newPage({viewport:{width:1440,height:1000},reducedMotion:'reduce'}),errors=[];p.on('pageerror',e=>errors.push(e.message));
  await p.goto((process.env.FRI_WEB_URL||require('node:url').pathToFileURL(path.resolve('FRI-website.html')).href)+'#downloads',{waitUntil:'load',timeout:60000});
  await p.waitForFunction(()=>window.FRI_WEBSITE?.evidence.entered);
  await p.locator('#intro').waitFor({state:'hidden'});
  assert.equal(await p.locator('.product-story,.widget-story').count(),8);
  assert.equal(await p.locator('.story-kicker,.hero-category,.hero-facts,.widget-proof').count(),0);
  assert.match(await p.locator('body').evaluate(el=>getComputedStyle(el).fontFamily),/BeVietnamPro/);
  assert(await p.evaluate(async()=>{await document.fonts.load('16px BeVietnamPro');return document.fonts.check('16px BeVietnamPro')}));
  assert.equal(await p.locator('[data-dialog="signup"],.answers,details').count(),0);
  for(const width of [320,390,768,1440]){
   await p.setViewportSize({width,height:1000});await p.evaluate(()=>{history.replaceState(null,'','#home');document.documentElement.style.scrollBehavior='auto';scrollTo(0,0)});
   await p.waitForFunction(()=>scrollY===0);
   const category=await p.locator('#hero-title').boundingBox(),proof=await p.locator('#downloads').boundingBox(),demo=await p.locator('#live-app').boundingBox();
   assert(category.height>0&&category.y>60,JSON.stringify({width,category,proof,demo,scroll:await p.evaluate(()=>scrollY)}));assert(demo.y>proof.y+proof.height+15,`Hero copy overlaps demo at ${width}`);
   assert(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
   await p.screenshot({path:`${output}/${name}-hero-${width}.png`});
  }
  await p.setViewportSize({width:1440,height:1000});
  for(const id of ['what','import','capture','prepare','conflicts','privacy','start']){
   const section=p.locator('#'+id);await section.scrollIntoViewIfNeeded();
   assert(!await section.locator('h2').evaluate(el=>getComputedStyle(el).clipPath.includes('inset')));
   await section.screenshot({path:`${output}/${name}-${id}.png`});
  }
  await p.setViewportSize({width:390,height:844});
  for(const id of ['what','import','capture','prepare','conflicts','privacy','start']){
   const section=p.locator('#'+id);await section.scrollIntoViewIfNeeded();await section.screenshot({path:`${output}/${name}-mobile-${id}.png`});
   const clipped=await section.locator('.scene').evaluate(scene=>{const r=scene.getBoundingClientRect();return [...scene.querySelectorAll('.week-paper,.workflow-stage,.prep-days,.local-device,.start-offer,.availability-grid')].some(el=>{const b=el.getBoundingClientRect();return b.left<r.left||b.right>r.right+1||b.bottom>r.bottom+1})});
   assert.equal(clipped,false,'Diagram clipped in '+id);
  }
  await p.setViewportSize({width:1440,height:1000});
  assert.match(await p.locator('#privacy').textContent(),/Your API key.*billed separately/s);
  assert.match(await p.locator('#import').textContent(),/No live sync/);
  assert.match(await p.locator('#start').textContent(),/In development/);
  await p.locator('.pricing-story-link').click();await p.waitForFunction(()=>FRI_WEBSITE.evidence.route==='pricing');
  assert.match(await p.locator('.plan-cost-note').textContent(),/billed separately/i);
  await p.locator('.free-plan .download-jump').click();await p.waitForFunction(()=>FRI_WEBSITE.evidence.route==='home');
  assert.equal(await p.locator('#downloads').isVisible(),true);
  await p.locator('#capture').scrollIntoViewIfNeeded();
  assert.equal(await p.locator('.workflow-card:visible').count(),1,'Reduced motion keeps one readable final card');
  await p.emulateMedia({reducedMotion:'no-preference'});
  await p.evaluate(()=>{const b=document.querySelector('#motion-access');if(b.getAttribute('aria-pressed')==='true')b.click()});
  await p.waitForFunction(()=>document.querySelector('.collect-scene').classList.contains('is-visible'));
  for(let time=0;time<9000;time+=100){
   const visible=await p.locator('.workflow-stage').evaluate((el,t)=>{el.getAnimations({subtree:true}).forEach(a=>{a.pause();a.currentTime=t});return [...el.querySelectorAll('.workflow-card')].map((c,i)=>({i,opacity:+getComputedStyle(c).opacity})).filter(c=>c.opacity>.5).map(c=>c.i)},time);
   assert.deepEqual(visible,[Math.floor(time/3000)],`Card sequence at ${time} ms`);
   if(time%3000===0)await p.locator('#capture').screenshot({path:`${output}/${name}-workflow-${time}.png`,animations:'allow'});
  }
  await p.locator('#import').scrollIntoViewIfNeeded();
  await p.waitForFunction(()=>document.querySelector('.sources-scene').classList.contains('is-visible'));
  await p.locator('#motion-access').evaluate(b=>{if(b.getAttribute('aria-pressed')!=='true')b.click()});
  assert.equal(await p.locator('.source-ticket').first().evaluate(el=>getComputedStyle(el).animationPlayState),'paused');
  assert.deepEqual(errors,[]);
  console.log('PASS',name,'clear offer/platforms, eight stories, four widths, CTA routes, reduced motion, 90 workflow frames, pause control');
 }finally{await browser.close()}
}})().catch(e=>{console.error(e);process.exitCode=1});
