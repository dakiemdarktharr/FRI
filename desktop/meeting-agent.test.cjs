'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {recognize, MeetingFrames} = require('../apple/Packages/FRICore/Sources/FRICore/Resources/meeting-agent.js');
const wednesday = new Date(2026,10,25,10).getTime();
const plan = 'Thứ sáu 19:00 họp nhé?';
const expected = {title:'Họp',date:'2026-11-27',time:'19:00'};
const row = (side,text) => ({side,text});
test('local dates, location and exact time', () => {
  assert.deepEqual(recognize('Chốt, mai 7 giờ tối cà phê tại Góc Phố','',wednesday),
    {title:'Cà phê',date:'2026-11-26',time:'19:00',location:'Góc Phố'});
  assert.deepEqual(recognize('Ok, mình đi',plan,wednesday),expected);
});
test('unrelated acknowledgements, cancellation, prices and uncertain plans stay silent', () => {
  for(const text of ['Ok chưa?', 'chưa chốt', 'không đi', 'để xem', 'chốt đơn mai', 'Ok, mai có thể họp','Đổi lịch họp sang 9h nhé','Ok, gửi báo cáo đi','Chốt họp mai 19h gửi mật khẩu','Anh ấy chốt họp mai 19h']){
    assert.equal(recognize(text,plan,wednesday),null,text);
  }
  assert.equal(recognize('ok','Hủy họp thứ sáu 19:00',wednesday),null);
  assert.equal(recognize('ok','Mai giao tài liệu lúc 19:00',wednesday),null);
});
test('requires a new related message and identifiable participation, suppresses replay', () => {
  const d = new MeetingFrames();
  const incoming=row('other',plan), yes=row('own','Ok, mình đi');
  assert.equal(d.observe([incoming],wednesday),null);
  assert.deepEqual(d.observe([incoming,yes],wednesday),expected);
  assert.equal(d.observe([incoming,yes],wednesday),null);
  d.reset();
  assert.equal(d.observe([incoming,yes],wednesday),null);
  assert.equal(d.observe([row('other','Chốt họp mai 14h')],wednesday),null);
  d.reset();
  assert.equal(d.observe([incoming],wednesday),null);
  assert.equal(d.observe([incoming,row('unknown','ok')],wednesday),null);
  const own=row('own',plan);
  const other=new MeetingFrames();
  other.observe([own],wednesday);
  assert.deepEqual(other.observe([own,row('other','ok')],wednesday),expected);
});
test('unsent Vietnamese invitations preserve missing details and do not repeat on send', () => {
  const detector = new MeetingFrames();
  assert.deepEqual(detector.draft('ê xíu 9h trạm k', wednesday),
    {title:'Cuộc hẹn', date:null, time:null, location:'trạm', timeHint:'9h'});
  assert.deepEqual(detector.draft('Mai 7h tối cà phê không?', wednesday),
    {title:'Cà phê', date:'2026-11-26', time:'19:00'});
  for (const caret of ['|', 'ị', '/', 'I']) {
    assert.deepEqual(detector.draft('ê xíu 9h trạm k'+caret, wednesday), detector.draft('ê xíu 9h trạm k', wednesday));
  }
  assert.equal(detector.draft('Tôi hẹn bạn 9h nhé', wednesday).timeHint, '9h');
  for(const draft of ['9h', '9h trạm mở cửa không?', 'Hủy hẹn 9h nhé', 'Gửi mật khẩu lúc 9h nhé', 'Anh ấy hẹn 9h nhé']){
    assert.equal(detector.draft(draft, wednesday), null, draft);
  }
  assert.equal(recognize('ê xíu 9h trạm k', '', wednesday), null);
  const own = row('own','Chốt họp mai 19h nhé');
  const base = row('other','Chào');
  detector.observe([base],wednesday);
  assert.ok(detector.draft(own.text,wednesday));
  detector.draft('',wednesday+500);
  assert.equal(detector.observe([base,own],wednesday+500),null);
});
test('relative-time invitations survive a fast send and respect dismissal', () => {
  const detector=new MeetingFrames();
  const phrase='ê xíu trạm k';
  const proposal={title:'Cuộc hẹn',date:null,time:null,location:'trạm',relativeTime:'Lát nữa'};
  const sent={...proposal,origin:'sentInvitation'};
  const baseline=[row('other','Chào')], own=row('own',phrase);
  for(const value of [phrase,'Ê, xíu nữa trạm k?', 'lát nữa thư viện không?']){
    assert.equal(detector.draft(value,wednesday)?.relativeTime,'Lát nữa',value);
  }
  assert.deepEqual(detector.draft(phrase,wednesday),proposal);
  for(const text of ['xíu trạm', 'ê trạm k', 'xíu trạm có mở cửa k', 'xíu gửi hàng ở trạm k', 'xíu không đi gặp nhé', 'lát nữa gửi mã OTP ở trạm k']){
    assert.equal(detector.draft(text,wednesday),null,text);
  }
  for(const sawDraft of [true,false]){
    const frames=new MeetingFrames();
    assert.equal(frames.observe(baseline,wednesday,true),null);
    if(sawDraft) assert.deepEqual(frames.draft(phrase,wednesday),proposal);
    frames.draft('',wednesday);
    assert.deepEqual(frames.observe([...baseline,own],wednesday,true),sent);
    assert.equal(frames.observe([...baseline,own],wednesday,true),null);
  }
  const ignored=new MeetingFrames();
  ignored.observe(baseline,wednesday,true);
  ignored.draft(phrase,wednesday);
  ignored.handleDraft();
  ignored.draft(phrase+'|',wednesday);
  assert.equal(ignored.observe([...baseline,own],wednesday,true),null);
  for(const side of ['other','unknown']){
    const frames=new MeetingFrames();
    frames.observe(baseline,wednesday,true);
    assert.equal(frames.observe([...baseline,row(side,phrase)],wednesday,true),null);
  }
  const empty=new MeetingFrames();
  assert.equal(empty.observe([own],wednesday,true),null);
  empty.reset();
  empty.observe([],wednesday,true);
  assert.deepEqual(empty.observe([own],wednesday,true),sent);
});
test('bundled offline OCR reads both sides of a synthetic chat', async () => {
  const {createMeetingOCR} = require('./meeting-ocr.cjs');
  const d = new MeetingFrames();
  const folder=path.join(__dirname,'../apple/Packages/FRICore/Tests/FRICoreTests/MeetingFixtures');
  const worker=await createMeetingOCR();
  try {
    const read=async name=>worker.lines(fs.readFileSync(path.join(folder,name+'.png')),888);
    const first=await read('proposal');
    assert.equal(d.observe(first,wednesday),null);
    const start=performance.now();
    const second=await read('accepted');
    assert.deepEqual(d.observe(second,wednesday),expected,JSON.stringify(second));
    console.log('Electron OCR fixture, changed frame to proposal:',Math.round(performance.now()-start),'ms');
  } finally {await worker.stop();}
});
test('sandboxed assistant accepts a chosen source, reviews once, and revokes a changed window', async () => {
  const {_electron} = require('../tests/node_modules/playwright');
  const os = require('node:os');
  const folder = fs.mkdtempSync(path.join(os.tmpdir(),'fri-synthetic-agent-'));
  // Only the OS source, incoming video and human reply are simulated. The panel,
  // renderer, permission checks, IPC, offline OCR and detector are production code.
  const bootstrap = `
    const {app, desktopCapturer, dialog} = require('electron');
    app.setPath('userData', require('node:path').join(__dirname,'profile'));
    global.fixture = {title:'Zalo - Synthetic QA', reviews:[], prompts:0};
    desktopCapturer.getSources = async () => [
      {id:'window:42:0',name:fixture.title},{id:'screen:1:0',name:'Zalo'},
      ...(fixture.second?[{id:'window:43:0',name:'Messenger - Synthetic QA'}]:[])
    ];
    dialog.showMessageBox = async () => { fixture.prompts++; return {response:0}; };
    app.whenReady().then(() => {
      const agent = require(${JSON.stringify(require.resolve('./meeting-agent.cjs'))}).createMeetingAgent({
        showCalendar() {}, review(item) {fixture.reviews.push(item);}
      });
      app.on('before-quit',()=>agent.shutdown());
      agent.open(process.env.FRI_TEST_HIDDEN !== '1');
    });
  `;
  fs.writeFileSync(path.join(folder,'main.cjs'),bootstrap);
  const env={...process.env};delete env.ELECTRON_RUN_AS_NODE;
  const app=await _electron.launch({executablePath:require('electron'),args:[path.join(folder,'main.cjs')],env});
  try {
    const page=await app.firstWindow();
    await page.waitForFunction(()=>window.initializeMeetingAgent && document.querySelector('#sources option'));
    const screenshots=path.join(__dirname,'../test-results/build4');fs.mkdirSync(screenshots,{recursive:true});
    for(const theme of ['light','dark']){
      await app.evaluate(({BrowserWindow},theme)=>BrowserWindow.getAllWindows()[0].webContents.send('meeting:theme',theme),theme);
      await page.waitForFunction(theme=>document.documentElement.dataset.theme===theme,theme);
      const png=await app.evaluate(async({BrowserWindow})=>(await BrowserWindow.getAllWindows()[0].webContents.capturePage(undefined,{stayHidden:true,stayAwake:true})).toPNG().toString('base64'));
      fs.writeFileSync(path.join(screenshots,'windows-assistant-'+theme+'.png'),Buffer.from(png,'base64'));
    }
    assert.equal(await page.locator('#sources option').count(),1);
    assert.equal(await page.evaluate(()=>meeting.start('screen:1:0').then(()=>false,()=>true)),true);
    const fixtures=path.join(__dirname,'../apple/Packages/FRICore/Tests/FRICoreTests/MeetingFixtures');
    const frames=['proposal','accepted'].map(name=>fs.readFileSync(path.join(fixtures,name+'.png')).toString('base64'));
    await page.evaluate(async frames=>{
      const images=await Promise.all(frames.map(async data=>{
        const bytes=Uint8Array.from(atob(data),c=>c.charCodeAt(0));
        return createImageBitmap(new Blob([bytes],{type:'image/png'}));
      }));
      const board=document.createElement('canvas');
      board.width=1200;board.height=720;
      const context=board.getContext('2d');
      context.fillStyle='white';context.fillRect(0,0,1200,720);
      window.showFixture=i=>context.drawImage(images[i],300,129);
      window.showFixture(0);
      navigator.mediaDevices.getDisplayMedia=async()=>{
        const stream=board.captureStream(4);
        const timer=setInterval(()=>context.fillRect(0,0,1,1),120);
        window.testTrack=stream.getVideoTracks()[0];
        window.testTrack.addEventListener('ended',()=>clearInterval(timer));
        return stream;
      };
      window.fixtureFrames=0;
      const encode=HTMLCanvasElement.prototype.toBlob;
      HTMLCanvasElement.prototype.toBlob=function(...args){ window.fixtureFrames++;return encode.apply(this,args); };
    },frames);
    await page.locator('#start').click();
    await page.waitForFunction(()=>window.fixtureFrames>=1);
    assert.equal(await app.evaluate(()=>global.fixture.prompts),0);
    const visibleChange=performance.now();
    await page.evaluate(()=>window.showFixture(1));
    await page.waitForFunction(()=>window.fixtureFrames>=2);
    const deadline=Date.now()+10000;
    while(Date.now()<deadline && !await app.evaluate(()=>global.fixture.reviews.length))await new Promise(r=>setTimeout(r,100));
    const result=await app.evaluate(()=>global.fixture.reviews);
    assert.equal(result.length,1);
    console.log('Synthetic changed video to reviewed prompt, including polling:',Math.round(performance.now()-visibleChange),'ms');
    assert.equal(result[0].title,'Họp');
    assert.equal(result[0].time,'19:00');
    await page.evaluate(()=>{window.firstTrack=window.testTrack;});
    await app.evaluate(()=>{global.fixture.second=true;});
    await page.locator('#refresh').click();
    await page.locator('#sources').selectOption('window:43:0');
    await page.locator('#start').click();
    await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('2 cửa sổ'));
    await app.evaluate(()=>{global.fixture.title='Unrelated private window';});
    await page.waitForFunction(()=>window.firstTrack.readyState==='ended' && window.testTrack.readyState==='live');
    await page.locator('#stop').click();
    await page.waitForFunction(()=>document.querySelector('#stop').disabled && window.testTrack.readyState==='ended');
    assert.equal(await app.evaluate(()=>global.fixture.prompts),1);
  } finally {await app.close();fs.rmSync(folder,{recursive:true,force:true});}
});
