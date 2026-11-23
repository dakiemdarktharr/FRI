(() => {
  'use strict';
  const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');
  const site=$('#site'), intro=$('#intro'), noise=$('#noise'), quiet=$('#quiet');
  const release='https://github.com/dakiemdarktharr/FRI/releases/download/v0.6.0/';
  const macRelease='https://github.com/dakiemdarktharr/FRI/releases/download/v0.5.0/';
  const releases='https://github.com/dakiemdarktharr/FRI/releases/tag/v0.6.0';
  const evidence={spamDuration:1300,events:[],demoFrames:0,seaFrames:0,os:'',entered:false};
  window.FRI_WEBSITE={evidence};
  site.inert=true;
  let introTimers=[],introRun=0,entered=false;
  const later=(fn,ms)=>{const id=setTimeout(fn,ms);introTimers.push(id);return id};
  const stamp=name=>evidence.events.push({name,time:performance.now()});
  function clearIntro(){introTimers.forEach(clearTimeout);introTimers=[]}
  function waveform(){return '<div class="waveform">'+Array.from({length:48},(_,i)=>'<i style="height:'+(6+Math.abs(Math.sin(i*2.3)*Math.cos(i*.44))*39)+'px"></i>').join('')+'</div>'}
  const cards=[
    {top:'MESSAGES',title:'One more thing…',body:'Could you take a look before tomorrow?',type:'message'},
    {top:'REMINDER',title:'You have a deadline.',body:'The proposal is due at 5:00 PM.',type:'popup'},
    {top:'CALENDAR',title:'November',body:'',type:'calendar'},
    {top:'VOICE NOTE',title:'Jamie · 0:42',body:'',type:'voice'},
    {top:'INBOX',title:'Quick follow-up',body:'Just checking this didn’t get lost.',type:'notification'},
    {top:'CALENDAR',title:'Two plans. Same time.',body:'Design review / Coffee with Jamie',type:'popup'},
    {top:'MESSAGES',title:'Are we still on?',body:'I sent you the details earlier.',type:'message'},
    {top:'REMINDER',title:'Starting in 5 minutes',body:'Weekly catch-up',type:'notification'},
    {top:'NOTES',title:'Don’t forget.',body:'The booking. The call. The thing for Friday.',type:'notification'},
    {top:'VOICE NOTE',title:'Alex · 1:08',body:'',type:'voice'}
  ];
  function cardHTML(c){
    let body='<p>'+c.body+'</p>';
    if(c.type==='calendar')body='<div class="mini-month">'+Array.from({length:28},(_,i)=>'<span>'+(i+1)+'</span>').join('')+'</div>';
    if(c.type==='voice')body=waveform()+'<div class="noise-top"><span>▶ VOICE RECORDING</span><span>1×</span></div>';
    if(c.type==='message')body='<div class="noise-message">'+c.body+'</div><div class="noise-message">Let me check my calendar.</div>';
    if(c.type==='popup')body+='<div class="noise-buttons"><span>Later</span><span>View</span></div>';
    return '<div class="noise-top"><span>'+c.top+'</span><span>NOW</span></div><h3>'+c.title+'</h3>'+body;
  }
  function addNoise(i,initial=false){
    const c=cards[i%cards.length],el=document.createElement('div');
    el.className='noise-card '+(i%5===0?'light-card':i%4===0?'wine-card':'');
    el.innerHTML=cardHTML(c);
    const cols=Math.max(2,Math.ceil(innerWidth/240)),rows=Math.ceil(innerHeight/150)+1;
    let x,y;
    if(initial){const initialPositions=[[.56,.15],[.3,.38],[.59,.47]][i];x=initialPositions[0]*innerWidth-140;y=initialPositions[1]*innerHeight}
    else {const n=i-3;const col=(n*5+Math.floor(n/cols))%cols,row=Math.floor(n/cols)%rows;x=col*(innerWidth/(cols-1))-100+(Math.sin(n*7)*43);y=row*135-60+Math.cos(n*3)*32}
    el.style.left=Math.round(x)+'px';el.style.top=Math.round(y)+'px';el.style.zIndex=i+1;
    noise.append(el);
  }
  function revealQuestion(){
    if(entered)return;
    stamp('question');intro.classList.add('question');quiet.hidden=false;$('#skip-intro').inert=true;$('#enter').focus({preventScroll:true});
  }
  function spam(){
    if(entered)return;
    stamp('spam-start');
    const n=Math.max(44,Math.ceil(innerWidth/220)*Math.ceil(innerHeight/130)*2);
    if(reduced.matches){for(let i=3;i<12;i++)addNoise(i)}
    else for(let i=0;i<n;i++)later(()=>{if(!entered)addNoise(i+3)},i*1300/n);
    later(()=>{if(!entered){stamp('spam-end');revealQuestion()}},1300);
  }
  function beginStory(){
    if(entered)return;
    $('#loader').style.opacity='0';later(()=>{$('#loader').hidden=true;stamp('black')},400);
    later(()=>{addNoise(0,true);stamp('notification')},950);
    later(()=>{addNoise(1,true);stamp('popup')},1580);
    later(()=>{addNoise(2,true);stamp('calendar')},2200);
    later(spam,2770);
  }
  async function startIntro(){
    clearIntro();const run=++introRun;entered=false;evidence.entered=false;evidence.events=[];
    intro.hidden=false;intro.classList.remove('leaving','question');quiet.hidden=true;noise.innerHTML='';
    $('#skip-intro').inert=false;$('#loader').hidden=false;$('#loader').style.opacity='1';
    document.body.classList.add('intro-active');site.inert=true;window.scrollTo(0,0);stamp('loading');
    const progress=v=>{$('#load-progress').style.width=v+'%';$('#load-value').textContent=v+'%'};
    progress(10);
    const surf=$('#surf');
    const ready=surf.readyState>=2?Promise.resolve():new Promise(resolve=>{surf.addEventListener('loadeddata',resolve,{once:true});surf.addEventListener('error',resolve,{once:true});setTimeout(resolve,8000)});
    const fonts=document.fonts.ready;
    await Promise.all([ready.then(()=>progress(65)),fonts.then(()=>progress(35)),new Promise(r=>setTimeout(r,reduced.matches?150:950))]);
    if(run!==introRun||entered)return;
    progress(100);later(beginStory,300);
  }
  function enterSite(){
    if(entered)return;
    entered=true;evidence.entered=true;introRun++;clearIntro();stamp('entered');
    intro.classList.add('leaving');intro.inert=true;site.inert=false;document.body.classList.remove('intro-active');
    setTimeout(()=>{intro.hidden=true;intro.inert=false},reduced.matches?0:850);
    $('#hero-title').setAttribute('tabindex','-1');$('#hero-title').focus({preventScroll:true});
    startTime=performance.now();lastFrame=startTime;
    if(!reduced.matches)$('#surf').play().catch(()=>{});
  }
  $('#enter').addEventListener('click',enterSite);$('#skip-intro').addEventListener('click',enterSite);
  document.addEventListener('keydown',e=>{
    if(!entered&&e.key==='Escape'){e.preventDefault();enterSite()}
    if(!entered&&!quiet.hidden&&e.key==='Tab'){e.preventDefault();$('#enter').focus()}
  });
  $('.skip-link').addEventListener('click',()=>{if(!entered)enterSite()});

  // Windows uses v0.6.0; macOS remains on the separately tested v0.5.0 development build. CPU architecture is never guessed.
  const platform=(navigator.userAgentData?.platform||navigator.platform||navigator.userAgent).toLowerCase();
  const touchMac=platform.includes('mac')&&navigator.maxTouchPoints>1;
  const os=platform.includes('win')?'windows':platform.includes('mac')&&!touchMac?'macos':'other';
  evidence.os=os;
  const iconWindows='<svg viewBox="0 0 20 20" width="16" height="16" fill="currentColor"><path d="M1 3l8-1v7H1zm9-1 9-1v8h-9zM1 10h8v7l-8-1zm9 0h9v9l-9-1z"/></svg>';
  const label=os==='windows'?'Download for Windows':os==='macos'?'Download for macOS':'Download Fri';
  $$('.download').forEach(a=>{
    a.querySelector('.download-label').textContent=label;
    if(os==='windows'){a.href=release+'FRI-0.6.0-win-x64.exe';a.querySelector('.os-icon').innerHTML=iconWindows;a.querySelector('.os-icon').style.width='15px'}
    else {a.href=releases;a.addEventListener('click',e=>{e.preventDefault();openDialog('download')})}
  });
  const dialog=$('#info-dialog');
  function options(){
    return '<div class="download-options"><a class="download-option" href="'+release+'FRI-0.6.0-win-x64.exe"><span>Windows<small>x64 · Unsigned</small></span><span>↓</span></a><a class="download-option" href="'+macRelease+'FRI-0.5.0-mac-arm64.dmg"><span>macOS<small>Apple silicon · Development build</small></span><span>↓</span></a><a class="download-option" href="'+macRelease+'FRI-0.5.0-mac-x64.dmg"><span>macOS<small>Intel · Development build</small></span><span>↓</span></a></div>';
  }
  function openDialog(type){
    if(type==='pricing'){
      $('#dialog-title').textContent='A little more time.';
      $('#dialog-content').innerHTML='<p>Pricing is still taking shape.</p><a class="pill dark" href="'+releases+'" target="_blank" rel="noopener noreferrer">Explore the preview <span>↗</span></a>';
    }else if(type==='signup'){
      $('#dialog-title').textContent='Your space. Soon.';
      $('#dialog-content').innerHTML='<p>Accounts aren’t open yet. The desktop app works without one.</p><button class="pill dark" id="choose-download">Get Fri <span>↓</span></button>';
      $('#choose-download').addEventListener('click',()=>openDialog('download'));
    }else{
      $('#dialog-title').textContent='Take a little space.';
      $('#dialog-content').innerHTML=options()+'<a class="dialog-release" href="'+releases+'" target="_blank" rel="noopener noreferrer">Windows 0.6.0 · Release notes ↗</a>';
    }
    if(!dialog.open)dialog.showModal();
    $('.dialog-close').focus();
  }
  $$('[data-dialog]').forEach(b=>b.addEventListener('click',()=>openDialog(b.dataset.dialog)));
  $('.dialog-close').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('click',e=>{const r=dialog.getBoundingClientRect();if(e.target===dialog&&(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom))dialog.close()});

  // A staged, read-only app demonstration. No calendar data is written.
  const cursor='<svg viewBox="0 0 22 28"><path d="M2 2v22l5-6 4 8 4-2-4-8h8Z"/></svg>';
  function task(title,time,period,duration,place,classes='',done=false){
    return '<div class="task-tile '+classes+(done?' completed':'')+'"><div class="task-meta"><span>Personal</span><span>'+duration+'</span></div><div class="task-time">'+time+'<small>'+period+'</small></div><div class="task-title">'+title+'</div><div class="task-place">'+place+'</div><span class="task-check '+(done?'done':'')+'">'+(done?'✓':'')+'</span></div>';
  }
  function appSkeleton(){
    return '<div class="app-chrome"><span class="traffic"><i></i><i></i><i></i></span><span>File</span><span>Edit</span><span>View</span><span>Help</span><span class="chrome-label">FRI</span></div><div class="app-body"><aside class="app-sidebar"><div class="app-brand">fri.<i class="search-glyph"></i></div><div class="app-today"><span>‹</span>Today<span>›</span></div><div class="app-new">＋ New</div><div class="app-nav current">▦ &nbsp; My day</div><div class="app-nav">▤ &nbsp; Calendar</div><div class="app-profile"><span class="app-avatar">A</span>Alex Morgan<span style="margin-left:auto">⚙</span></div></aside><div class="app-content"><div class="app-date"><div><h3>Sunday</h3><p>November 22, 2026</p></div><div class="app-date-ring"><svg viewBox="0 0 50 50"><circle class="ring-track" cx="25" cy="25" r="22"/><circle class="ring-fill" cx="25" cy="25" r="22"/></svg><span>✓</span></div></div><div class="app-mosaic"><div class="task-column">'+task('A slow start','8:00','AM','30m','At home','',true)+task('Make something meaningful','9:00','AM','2h','The studio','dark-tile tall')+'</div><div class="task-column coffee-column">'+task('A little room to read','4:00','PM','1h','Your favourite corner','tall')+'</div><div class="task-column"><div class="task-upnext"><span>UP NEXT</span><div class="upnext-line"></div><h4>9:00 <small>AM</small></h4><b>Make something<br>meaningful</b><p>The studio</p></div><div class="app-dot"><i></i><span>Day</span></div></div></div><div class="demo-overlay"><div class="demo-form"></div></div><div class="demo-cursor">'+cursor+'</div></div></div>';
  }
  const apps=[$('#live-app')];
  apps.forEach(a=>{a.innerHTML=appSkeleton();a.setAttribute('aria-hidden','true')});
  let elapsed=reduced.matches?9000:0,paused=reduced.matches,lastFrame=performance.now(),startTime=lastFrame,lastKey='',lastChapter=-1;
  function formHTML(mode,typed,chosen){
    if(mode==='add')return '<div class="form-kicker">NEW SCHEDULE</div><h4>What’s the plan?</h4><div class="demo-field">'+typed+'<i class="typing-caret"></i></div><div class="form-row"><span class="form-chip">Today</span><span class="form-chip">＋ Add details</span></div><div class="demo-submit">Done</div>';
    return '<div class="form-kicker">ONE LAST DETAIL</div><h4>When’s coffee?</h4><div class="form-row"><span class="form-chip '+(chosen?'selected':'')+'">11:30 AM</span><span class="form-chip">45 minutes</span></div><div class="demo-submit">Add to my day</div>';
  }
  function renderDemo(){
    const t=elapsed%16000;
    const chapter=t<4200?0:t<8500?1:2;
    const mode=chapter===0?'add':chapter===1?'clarify':'calendar';
    const typed='Coffee with Jamie'.slice(0,Math.max(0,Math.floor((t-650)/90)));
    const chosen=t>5700;
    const done=t>=12000;
    const key=mode+typed+chosen+done+(t>3100)+(t>7400)+(t>11000);
    if(key===lastKey)return;lastKey=key;evidence.demoFrames++;
    if(chapter!==lastChapter){lastChapter=chapter;$$('[data-step]').forEach((b,i)=>{b.classList.toggle('active',i===chapter);b.setAttribute('aria-pressed',String(i===chapter))})}
    apps.forEach(a=>{
      const overlay=a.querySelector('.demo-overlay'),form=a.querySelector('.demo-form'),arrow=a.querySelector('.demo-cursor');
      overlay.classList.toggle('hidden',mode==='calendar');
      if(mode!=='calendar')form.innerHTML=formHTML(mode,typed,chosen);
      arrow.style.opacity=t>13800?'0':'1';
      arrow.style.left=mode==='add'?(t>3100?'58%':'47%'):mode==='clarify'?(t>7400?'58%':'49%'):'29%';
      arrow.style.top=mode==='add'?(t>3100?'65%':'48%'):mode==='clarify'?(t>7400?'61%':'49%'):'87%';
      arrow.classList.toggle('click',(t>3100&&t<3550)||(t>7400&&t<7850)||(t>12000&&t<12450));
      const column=a.querySelector('.coffee-column');
      if(mode==='calendar'&&!column.querySelector('.new-task'))column.insertAdjacentHTML('afterbegin',task('Coffee with Jamie','11:30','AM','45m','The little coffee shop','new-task'));
      if(mode!=='calendar')column.querySelector('.new-task')?.remove();
      const work=a.querySelector('.dark-tile');work.classList.toggle('completed',done);
      work.querySelector('.task-check').classList.toggle('done',done);work.querySelector('.task-check').textContent=done?'✓':'';
      a.querySelector('.ring-fill').style.strokeDashoffset=done?'55':'100';
      const toast=a.querySelector('.demo-toast');
      if(mode==='calendar'&&!toast){const e=document.createElement('div');e.className='demo-toast';e.textContent=done?'A little more room. ✓':'Coffee with Jamie · Added ✓';a.querySelector('.app-content').append(e)}
      if(toast)toast.textContent=done?'A little more room. ✓':'Coffee with Jamie · Added ✓';
      if(mode!=='calendar')toast?.remove();
    });
  }
  function updatePause(){
    $('#motion-access').textContent=paused?'Play animations':'Pause animations';
    $('#motion-access').setAttribute('aria-pressed',String(paused));
  }
  function setChapter(n){elapsed=[0,4400,9000][n];lastKey='';renderDemo();$('#demo-status').textContent=['Add your plans.','Fill in the missing time.','Your appointment is on the calendar.'][n]}
  $$('[data-step]').forEach(b=>b.addEventListener('click',()=>setChapter(Number(b.dataset.step))));
  $$('[data-demo-jump]').forEach(b=>b.addEventListener('click',()=>{setChapter(Number(b.dataset.demoJump));$('#demo').scrollIntoView({behavior:reduced.matches?'instant':'smooth'})}));
  $('#motion-access').addEventListener('click',()=>{paused=!paused;updatePause();syncVideo()});
  updatePause();renderDemo();

  let motionTime=0,reviewFrozen=false,seaVisible=true,demoVisible=true,widgetVisible=false;
  const visibilityObserver=new IntersectionObserver(entries=>{for(const e of entries){if(e.target.id==='home')seaVisible=e.isIntersecting;else if(e.target.id==='widget-demo')widgetVisible=e.isIntersecting;else demoVisible=e.isIntersecting}syncVideo()},{rootMargin:'100px'});
  function syncVideo(){const v=$('#surf');if(entered&&seaVisible&&!document.hidden&&!paused&&!reviewFrozen)v.play().catch(()=>{});else v.pause();const widget=$('#widget-demo');if(entered&&widgetVisible&&!document.hidden&&!paused)widget.play().catch(()=>{});else widget.pause()}
  visibilityObserver.observe($('#home'));visibilityObserver.observe($('#demo'));visibilityObserver.observe($('#widget-demo'));document.addEventListener('visibilitychange',syncVideo);
  function frame(now){
    const dt=Math.min(now-lastFrame,60);lastFrame=now;
    if(entered&&!document.hidden&&!paused&&!reviewFrozen){elapsed+=dt;motionTime+=dt/1000;if(demoVisible)renderDemo();window.FRI_MOTION?.render(motionTime)}
    requestAnimationFrame(frame);
  }
  reduced.addEventListener('change',()=>{if(reduced.matches){paused=true;syncVideo();updatePause()}});
  window.FRI_WEBSITE.review={async seek(seconds){reviewFrozen=true;elapsed=seconds*1000;lastKey='';renderDemo();const v=$('#surf');v.pause();if(v.readyState<2)await Promise.race([new Promise(r=>v.addEventListener('loadeddata',r,{once:true})),new Promise(r=>setTimeout(r,1500))]);if(v.readyState<2){window.FRI_MOTION?.render(seconds,true);return}const time=Number.isFinite(v.duration)?seconds%v.duration:0;if(Math.abs(v.currentTime-time)>.001)await new Promise(resolve=>{let timer;const done=ok=>{clearTimeout(timer);v.removeEventListener('seeked',onSeek);v.removeEventListener('error',onError);if(!ok)evidence.reviewSeekTimeouts=(evidence.reviewSeekTimeouts||0)+1;resolve()};const onSeek=()=>done(true),onError=()=>done(false);v.addEventListener('seeked',onSeek,{once:true});v.addEventListener('error',onError,{once:true});timer=setTimeout(()=>done(false),1500);v.currentTime=time});window.FRI_MOTION?.render(seconds,true)},resume(){reviewFrozen=false;if(!paused)$('#surf').play().catch(()=>{})},chapter:setChapter};
  requestAnimationFrame(frame);
  if(location.pathname.includes('/pricing')||location.hash==='#pricing')enterSite();else startIntro();
})();
