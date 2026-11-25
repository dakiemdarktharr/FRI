'use strict';
const {app, BrowserWindow, desktopCapturer, dialog, ipcMain, Menu, session, Tray} = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {createHash} = require('node:crypto');
const {pathToFileURL} = require('node:url');

const page = pathToFileURL(path.join(__dirname, 'meeting-agent.html')).href;
const fingerprint = name => createHash('sha256').update(name.replace(/^\(\d+\)\s*/, '')).digest('hex');
function chatWindow(source) {
  return source.id.startsWith('window:') && !/^FRI\b/i.test(source.name)
    && !/đăng nhập|mật khẩu|xác thực|thanh toán|password|sign in|login|payment|verification/i.test(source.name)
    && /(?:^|[·|—–( -])(Messenger|Zalo)(?:$|[·|—–) -])/i.test(source.name);
}

function login(value) {
  if (process.platform !== 'linux') {
    if (typeof value === 'boolean') app.setLoginItemSettings({openAtLogin:value});
    return app.getLoginItemSettings().openAtLogin;
  }
  const entry = path.join(process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config'), 'autostart', 'fri-meeting-agent.desktop');
  if (value === false) fs.rmSync(entry, {force:true});
  if (value === true) {
    if (!app.isPackaged) throw Error('Install the desktop build before enabling startup.');
    const exe = process.env.APPIMAGE || process.execPath;
    const quoted = '"' + exe.replace(/[%]/g,'%%').replace(/["`$\\]/g,'\\$&') + '"';
    fs.mkdirSync(path.dirname(entry), {recursive:true});
    fs.writeFileSync(entry, '[Desktop Entry]\nType=Application\nName=FRI\nExec=' + quoted + '\n', {mode:0o600});
  }
  return fs.existsSync(entry);
}

function createMeetingAgent({showCalendar, review, getTheme=()=> 'system'}) {
  const {MeetingFrames} = require('./ui/meeting-agent.js');
  const capture = session.fromPartition('fri-window-capture');
  const portal = process.platform === 'linux' && (process.env.XDG_SESSION_TYPE === 'wayland' || !!process.env.WAYLAND_DISPLAY);
  const file = path.join(app.getPath('userData'), 'meeting-window.json');
  let saved = [];
  try {
    const previous = JSON.parse(fs.readFileSync(file, 'utf8'));
    saved = (Array.isArray(previous) ? previous : [previous]).filter(s => s?.id && s?.label);
  } catch {}
  const grants = new Map();
  let portalChoices = [], nextToken = 0, requested = null, panel, tray, quitting = false, ocr;
  let recognitionQueue = Promise.resolve(), promptQueue = Promise.resolve();

  const sources = async () => (await desktopCapturer.getSources({
    types:['window'], thumbnailSize:{width:0,height:0}, fetchWindowIcons:false
  })).filter(chatWindow);
  function persist() {
    if (portal || !saved.length) { fs.rmSync(file, {force:true}); return; }
    fs.writeFileSync(file + '.pending', JSON.stringify(saved), {mode:0o600});
    fs.renameSync(file + '.pending', file);
  }
  function menu() {
    if (!tray) return;
    tray.setToolTip(grants.size ? 'FRI · Đang nhận diện cửa sổ chat' : 'FRI · Thư ký lịch');
    tray.setContextMenu(Menu.buildFromTemplate([
      {label:'Thư ký lịch…', click:()=>open(true)},
      {label:'Mở lịch FRI', click:showCalendar},
      {label:'Tắt nhận diện', enabled:!!grants.size, click:()=>stop()},
      {type:'separator'}, {label:'Thoát FRI', click:()=>app.quit()}
    ]));
  }
  function stop(message='Đang tắt', token=null, remember=false) {
    const old = grants.get(token);
    if (token !== null && !old) return;
    if (old) grants.delete(token); else grants.clear();
    if (requested === token || token === null) requested = null;
    if (!remember) {
      saved = old ? saved.filter(s=>s.id!==old.id) : [];
      persist();
    }
    if (!grants.size) {
      portalChoices = [];
      const engine = ocr;
      ocr = null;
      // Let work already submitted complete. Its token can no longer publish.
      if (engine) void recognitionQueue.then(()=>engine).then(worker=>worker.stop()).catch(()=>{});
    }
    if (panel && !panel.isDestroyed()) panel.webContents.send('meeting:stopped', {message,token});
    menu();
  }
  async function matching(token) {
    const grant = grants.get(token);
    if (!grant) return null;
    // Re-enumerating a PipeWire session would reopen its OS chooser.
    const current = (portal ? portalChoices : await sources()).find(s=>s.id===grant.id && fingerprint(s.name)===grant.label);
    if (!grants.has(token)) return null;
    if (!current) stop('Cửa sổ đóng hoặc đổi tên. Chọn lại cửa sổ chat.', token);
    return current;
  }
  capture.setDisplayMediaRequestHandler((request, callback)=>{
    const token = requested;
    requested = null;
    if (!panel || request.frame!==panel.webContents.mainFrame || request.frame.url!==page || request.audioRequested || !grants.has(token)) {
      callback(null); return;
    }
    matching(token).then(source=>callback(source ? {video:source} : null)).catch(()=>callback(null));
  });
  capture.webRequest.onBeforeRequest({urls:['http://*/*','https://*/*']}, (_d,cb)=>cb({cancel:true}));
  capture.setPermissionRequestHandler((wc,p,cb)=>cb(wc===panel?.webContents && p==='display-capture'));
  capture.setPermissionCheckHandler((wc,p)=>wc===panel?.webContents && p==='display-capture');

  function handle(name, fn) {
    ipcMain.handle('meeting:'+name, (e,...args)=>{
      if (!panel || e.sender!==panel.webContents || e.senderFrame!==panel.webContents.mainFrame || e.senderFrame.url!==page) throw Error('Unknown meeting window');
      return fn(...args);
    });
  }
  handle('sources', async()=>{
    const list=portal && grants.size ? portalChoices : await sources();
    if (portal) portalChoices=list;
    return list.map(({id,name})=>({id,name}));
  });
  handle('state', async()=>{
    const list=saved.length && !portal ? await sources() : [];
    const resume=list.filter(s=>saved.some(g=>g.id===s.id && g.label===fingerprint(s.name))).map(s=>s.id);
    return {login:login(),portal,resume,theme:getTheme()};
  });
  handle('login', value=>{
    if (typeof value!=='boolean') throw Error('Invalid preference');
    return login(value);
  });
  handle('start', async id=>{
    const source=(portal ? portalChoices : await sources()).find(s=>s.id===id);
    if (!source || [...grants.values()].some(g=>g.id===id) || (portal && grants.size)) throw Error('Unavailable chat window');
    const token=++nextToken, label=fingerprint(source.name);
    grants.set(token,{id,label,detector:new MeetingFrames()});
    requested=token;
    if (!portal) { saved=[...saved.filter(s=>s.id!==id),{id,label}]; persist(); }
    if (!ocr) {
      const engine=require('./meeting-ocr.cjs').createMeetingOCR();
      ocr=engine;
      void engine.catch(()=>{ if(ocr===engine) stop('Không thể khởi động bộ đọc chữ cục bộ.'); });
    }
    menu();
    return token;
  });
  handle('check', async token=>!!await matching(token));
  handle('stop', token=>stop('Đã tắt nhận diện.',token??null));
  function suggest(token, item) {
    promptQueue=promptQueue.then(async()=>{
      if (!grants.has(token)) return;
      const detail=[item.title,item.date||'Chưa rõ ngày',item.time||'Chưa rõ giờ',item.location].filter(Boolean).join(' · ');
      const {response}=await dialog.showMessageBox({type:'question',title:'FRI · Thư ký lịch',
        message:'Thêm vào lịch FRI?',detail,buttons:['Xem và lưu','Bỏ qua'],defaultId:1,cancelId:1});
      if(response===0 && grants.has(token)) review(item);
    }).catch(()=>{});
  }
  handle('frame', (token,bytes,width)=>{
    const grant=grants.get(token), engine=ocr;
    if (!grant || grant.busy || !engine || !(bytes instanceof Uint8Array) || bytes.length>6*1024*1024 || !Number.isInteger(width) || width<=0 || width>1280) return;
    grant.busy=true;
    recognitionQueue=recognitionQueue.then(async()=>{
      if (!grants.has(token) || !(await matching(token))) return;
      const rows=await (await engine).lines(Buffer.from(bytes),width);
      if (!(await matching(token))) return;
      const item=grant.detector.observe(rows);
      if (item) suggest(token,item);
    }).catch(()=>stop('Bộ đọc chữ tạm dừng. Kiểm tra nguồn và quyền chia sẻ.',token)).finally(()=>{grant.busy=false;});
    return recognitionQueue;
  });
  function open(visible=true) {
    if (panel) {panel.webContents.send('meeting:theme',getTheme());if(visible){panel.show();panel.focus();} return;}
    if (!tray) {tray=new Tray(path.join(__dirname,'resources/icon.png')); tray.on('click',()=>open(true)); menu();}
    panel=new BrowserWindow({width:560,height:640,minWidth:400,minHeight:560,show:visible,title:'FRI · Thư ký lịch',webPreferences:{
      session:capture,preload:path.join(__dirname,'meeting-preload.cjs'),sandbox:true,contextIsolation:true,nodeIntegration:false,backgroundThrottling:false
    }});
    panel.removeMenu();
    panel.webContents.setWindowOpenHandler(()=>({action:'deny'}));
    panel.webContents.on('will-navigate',e=>e.preventDefault());
    panel.webContents.on('render-process-gone',()=>stop('Cửa sổ chia sẻ đã đóng.'));
    panel.on('close',e=>{if(!quitting&&grants.size){e.preventDefault();panel.hide();}});
    panel.on('closed',()=>{panel=null;if(!quitting){stop();tray?.destroy();tray=null;}});
    panel.loadURL(page).then(()=>panel?.webContents.executeJavaScript('window.initializeMeetingAgent()',true)).catch(()=>stop('Chưa mở được cửa sổ.'));
  }
  return {open,active:()=>!!grants.size,resume:()=>{if(saved.length&&!portal)open(false);},
    shutdown:()=>{quitting=true;stop('Đang thoát',null,true);panel?.destroy();tray?.destroy();tray=null;}};
}
module.exports={createMeetingAgent};
