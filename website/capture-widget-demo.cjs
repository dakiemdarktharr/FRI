// Capture the actual Electron UI in an isolated profile. A neutral virtual desktop
// presents its window frames, so recording never exposes or steals the user's desktop.
const {chromium,_electron}=require('../tests/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
(async()=>{
 const output=path.resolve('test-results/cloud/widget-film');fs.mkdirSync(output,{recursive:true});
 const profile=fs.mkdtempSync(path.join(output,'profile-'));
 const env={...process.env,FRI_TEST_MODE:'1',FRI_TEST_HIDDEN:'1',FRI_TEST_USER_DATA:profile};delete env.ELECTRON_RUN_AS_NODE;
 const app=await _electron.launch({executablePath:process.env.FRI_TEST_EXE||path.resolve('dist/win-unpacked/FRI.exe'),args:[],env});
 const browser=await chromium.launch();let video;
 try{
  const main=await app.firstWindow();await main.waitForFunction(()=>window.FRI_PREVIEW);
  await main.evaluate(async()=>{const {state}=await friDesktop.loadState(),s=structuredClone(state),d=new Date(),date=[d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-');s.settings.theme='light';s.tasks=['Finish the concept','Coffee with Jamie','A little room to read'].map((title,i)=>({id:'film-'+i,title,date,time:['09:00','11:30','16:00'][i],duration:[90,30,60][i],category:'Personal',kind:'schedule',location:['The studio','The little coffee shop','At home'][i],notes:'',done:false}));await friDesktop.saveState(state,s)});
  await app.evaluate(({BrowserWindow})=>{const w=BrowserWindow.getAllWindows().find(w=>w.webContents.getURL()==='app://fri/index.html');w.setBounds({x:80,y:80,width:1200,height:800})});
  const context=await browser.newContext({viewport:{width:1280,height:800},recordVideo:{dir:output,size:{width:1280,height:800}},reducedMotion:'reduce'}),view=await context.newPage();video=view.video();
  await view.setContent('<html><style>*{box-sizing:border-box}body{margin:0;background:#eaf0f4;color:#172b3a;font-family:system-ui;overflow:hidden}#label{position:absolute;left:56px;top:38px;font-size:24px;font-weight:600;letter-spacing:-.6px}#frame{position:absolute;object-fit:fill;border-radius:18px;filter:drop-shadow(0 20px 32px #172b3a22)}#pointer{position:absolute;width:18px;height:22px;z-index:5;clip-path:polygon(0 0,100% 66%,55% 69%,37% 100%);background:#172b3a;filter:drop-shadow(0 0 1px white)}</style><div id="label">Your day, within reach.</div><img id="frame"><div id="pointer"></div></html>');
  const frame=async(page,rect,label,cursor)=>{
   const png=await app.evaluate(async({BrowserWindow},url)=>{const w=BrowserWindow.getAllWindows().find(w=>w.webContents.getURL()===url);return (await w.webContents.capturePage(undefined,{stayHidden:true,stayAwake:true})).toPNG().toString('base64')},page.url());
   await view.evaluate(async({png,rect,label,cursor})=>{const el=document.querySelector('#frame');el.src='data:image/png;base64,'+png;Object.assign(el.style,{display:'block',left:rect[0]+'px',top:rect[1]+'px',width:rect[2]+'px',height:rect[3]+'px'});await el.decode();if(label)document.querySelector('#label').textContent=label;if(cursor)Object.assign(document.querySelector('#pointer').style,{left:cursor[0]+'px',top:cursor[1]+'px'})},{png,rect,label,cursor});
  };
  const hold=ms=>view.waitForTimeout(ms);
  await frame(main,[170,110,960,640],null,[200,122]);await hold(1800);
  await main.locator('[data-menu=file]').click();await frame(main,[170,110,960,640],'File → Create FRI widget on desktop',[222,130]);await hold(1800);
  const waitSelector=app.waitForEvent('window');await main.locator('[data-command=desktop-widget]').click();const selector=await waitSelector;await selector.waitForLoadState();
  await selector.mouse.move(420,260);await selector.mouse.down();
  for(let i=1;i<=20;i++){await selector.mouse.move(420+320*i/20,260+320*i/20);await frame(selector,[0,0,1280,800],'Draw a space for your day.',[520+i*10,260+i*10]);await hold(35)}
  const waitWidget=app.waitForEvent('window');await selector.mouse.up();const widget=await waitWidget;await widget.locator('#task').filter({hasText:'Finish the concept'}).waitFor();
  await widget.evaluate(()=>friWidget.bounds({x:420,y:260,width:320,height:320}));await frame(widget,[420,210,320,320],'Start with what matters now.',[720,230]);await hold(1800);
  for(let i=1;i<=20;i++){await widget.evaluate(i=>friWidget.bounds({x:420+i*10,y:260,width:320,height:320}),i);await frame(widget,[420+i*10,210,320,320],'Move it with you.',[440+i*10,225]);await hold(25)}
  for(let i=1;i<=24;i++){const w=Math.round(320+300*i/24),h=Math.round(320+240*i/24);await widget.evaluate(({w,h})=>friWidget.bounds({x:620,y:220,width:w,height:h}),{w,h});await frame(widget,[610,130,w,h],'More space. More of your day.',[610+w-12,130+h-12]);await hold(35)}
  const largeFont=await widget.locator('#task').evaluate(el=>getComputedStyle(el).fontSize);assert.equal(largeFont,'18px');await hold(2000);
  await widget.locator('#done').click();await widget.locator('#task').filter({hasText:'Coffee with Jamie'}).waitFor();await frame(widget,[610,130,620,560],'Done. On to what’s next.',[1184,270]);await hold(2300);
  await widget.locator('#options').click();await frame(widget,[610,130,620,560],'Remove the widget. Keep your plans.',[1198,152]);await hold(1500);
  await widget.locator('[data-action=remove]').click().catch(e=>{if(!widget.isClosed())throw e});await view.evaluate(()=>{document.querySelector('#frame').style.display='none';document.querySelector('#label').textContent='A little space. A clearer day.'});await hold(1700);
  await context.close();const source=await video.path();
  execFileSync('ffmpeg',['-y','-i',source,'-vf','fps=24','-c:v','libx264','-preset','slow','-crf','23','-pix_fmt','yuv420p','-an','-movflags','+faststart','website/assets/widget-walkthrough.mp4'],{stdio:'ignore',windowsHide:true});
  execFileSync('ffmpeg',['-y','-i','website/assets/widget-walkthrough.mp4','-c:v','libvpx-vp9','-b:v','0','-crf','34','-an','website/assets/widget-walkthrough.webm'],{stdio:'ignore',windowsHide:true});
  execFileSync('ffmpeg',['-y','-ss','12','-i','website/assets/widget-walkthrough.mp4','-frames:v','1','-update','1','website/assets/widget-poster.jpg'],{stdio:'ignore',windowsHide:true});
  console.log('Recorded actual native widget creation, movement, responsive resize, completion and removal.');
 }finally{await app.close().catch(()=>{});await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
