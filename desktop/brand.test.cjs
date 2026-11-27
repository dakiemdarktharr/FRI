const {readUsageGuide} = require('./scripts/read-usage-guide.cjs');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{_electron}=require('../tests/node_modules/playwright');
test('opaque Fri surfaces retain translucent workspace and readable widget detail',async()=>{
 fs.mkdirSync(path.join(__dirname,'test-results'),{recursive:true});
 const env={...process.env,FRI_TEST_MODE:'1',FRI_TEST_USER_DATA:fs.mkdtempSync(path.join(__dirname,'test-results/brand-'))};delete env.ELECTRON_RUN_AS_NODE;
 const app=await _electron.launch({executablePath:process.env.FRI_TEST_EXE||require('electron'),args:process.env.FRI_TEST_EXE?[]:[__dirname],env});
 try{const p=await app.firstWindow();await readUsageGuide(p);await p.waitForFunction(()=>window.FRI_PREVIEW);await p.evaluate(()=>FRI_COMMAND('deadline'));await p.locator('[name=title]').fill('A clear, opaque plan');await p.locator('[name=time]').fill('23:00');await p.locator('#appointment-form button[value=done]').click();
 const surfaces=async selectors=>p.evaluate(list=>list.map(s=>{const el=document.querySelector(s);if(!el)throw Error('Missing '+s);const c=getComputedStyle(el);return {selector:s,color:c.backgroundColor,opacity:c.opacity,filter:c.backdropFilter}}),selectors);
 const assertOpaque=rows=>rows.forEach(r=>{assert.match(r.color,/^rgb\(/,r.selector);assert.equal(r.opacity,'1',r.selector)});
 assertOpaque(await surfaces(['.feed-card','.feed-open','.task-toggle','.date-card','.widget','.next-open','.new-button','#refresh-sources']));
 const caption=await p.locator('.widget-caption').first().evaluate(el=>getComputedStyle(el).color);assert.equal(caption,'rgb(88, 109, 124)');
 const material=await p.locator('.main-material').evaluate(el=>({color:getComputedStyle(el).backgroundColor,solid:matchMedia('(prefers-reduced-transparency: reduce)').matches||document.documentElement.classList.contains('solid-glass')||document.documentElement.dataset.material==='solid'}));if(material.solid)assert.equal(material.color,'rgb(244, 247, 250)');else assert.match(material.color,/^rgba\(/);
 await p.evaluate(()=>FRI_COMMAND('widgets'));await p.waitForFunction(()=>getComputedStyle(document.querySelector('#modal')).opacity==='1');assertOpaque(await surfaces(['#modal','.menu-option']));assert.equal((await surfaces(['#modal']))[0].filter,'none');
 await p.evaluate(()=>document.querySelector('#modal').close());
 await p.evaluate(()=>FRI_COMMAND('settings'));await p.locator('#theme-mode').selectOption('dark');await p.getByRole('button',{name:'Done',exact:true}).click();
 assertOpaque(await surfaces(['.feed-card','.task-toggle','.date-card','.new-button']));
 assert.equal(await p.locator('.feed-card').first().evaluate(el=>getComputedStyle(el).backgroundColor),'rgb(34, 40, 51)');
 assert.equal(await p.locator('.new-button').evaluate(el=>getComputedStyle(el).color),'rgb(20, 24, 31)');
 assert.equal(await p.evaluate(async()=>(await document.fonts.load('600 18px BeVietnamPro','Lịch hẹn · Nguyễn · Ắ Ỗ Ữ Ỵ')).length),1,'bundled Vietnamese font loads under packaged CSP');
 await p.screenshot({path:path.join(__dirname,'test-results/dark-appearance.png')});
 }finally{await app.close()}
});
