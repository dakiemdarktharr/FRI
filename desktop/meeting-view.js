'use strict';
const api=window.meeting;
const ui=id=>document.getElementById(id);
const sessions=new Map();
let starting=false;
function updateButtons() {
  const id=ui('sources').value;
  ui('start').disabled=starting || !id || [...sessions.values()].some(s=>s.id===id);
  ui('stop').disabled=!sessions.size;
  ui('stop').hidden=!sessions.size;
  ui('start').hidden=[...sessions.values()].some(s=>s.id===id);
}
function release(s) {
  if (!s) return;
  clearTimeout(s.timer);
  s.stream?.getTracks().forEach(track=>track.stop());
  s.video.srcObject=null;
  s.stamp.width=0;
  s.canvas.width=0;
  s.pixels=null;
  sessions.delete(s.token);
}
function stopped({message,token}) {
  if (token===null) [...sessions.values()].forEach(release);
  else release(sessions.get(token));
  ui('status').textContent=message+(sessions.size?' · Còn '+sessions.size+' cửa sổ đang bật.':'');
  updateButtons();
}
async function refresh() {
  try {
    const list=await api.sources();
    ui('sources').replaceChildren(...list.map(s=>new Option(s.name,s.id)));
    updateButtons();
    if(!list.length && !sessions.size) ui('status').textContent='Mở Zalo hoặc Messenger trong cửa sổ riêng rồi tìm lại.';
  } catch {ui('status').textContent='Hệ thống chưa cho phép chọn cửa sổ chat.';}
}
async function tick(s) {
  const live=()=>sessions.has(s.token);
  if (!live()) return;
  try {
    if (!await api.check(s.token) || !live()) return;
    const width=s.video.videoWidth, height=s.video.videoHeight;
    if(width && height) {
      const x=Math.floor(width*.25), y=Math.floor(height*.18), w=Math.floor(width*.74), h=Math.floor(height*.68);
      s.small.drawImage(s.video,x,y,w,h,0,0,s.stamp.width,s.stamp.height);
      const pixels=s.small.getImageData(0,0,s.stamp.width,s.stamp.height).data;
      const changed=!s.pixels || pixels.some((v,i)=>i%4!==3 && Math.abs(v-s.pixels[i])>12);
      if(changed) {
        s.pixels=pixels;
        s.canvas.width=Math.min(w,1280);s.canvas.height=Math.round(h*s.canvas.width/w);
        const ctx=s.canvas.getContext('2d');
        ctx.drawImage(s.video,x,y,w,h,0,0,s.canvas.width,s.canvas.height);
        const blob=await new Promise(resolve=>s.canvas.toBlob(resolve,'image/png'));
        if (!live()) return;
        const bytes=new Uint8Array(await blob.arrayBuffer());
        if (!live()) return;
        await api.frame(s.token,bytes,s.canvas.width);
        ctx.clearRect(0,0,s.canvas.width,s.canvas.height);
      }
    }
  } catch {if(live())await api.stop(s.token);return;}
  if(live())s.timer=setTimeout(()=>tick(s),500);
}
async function start(id) {
  if(starting || !id || [...sessions.values()].some(s=>s.id===id))return;
  starting=true;
  updateButtons();
  let token;
  try {
    token=await api.start(id);
    const video=document.createElement('video'), stamp=document.createElement('canvas');
    video.muted=true;stamp.width=128;stamp.height=80;
    const s={id,token,video,stamp,small:stamp.getContext('2d',{willReadFrequently:true}),canvas:document.createElement('canvas')};
    sessions.set(token,s);
    const stream=await navigator.mediaDevices.getDisplayMedia({video:{frameRate:2},audio:false});
    if(!sessions.has(token)){stream.getTracks().forEach(t=>t.stop());return;}
    s.stream=stream;
    const track=stream.getVideoTracks()[0];
    if(!track || track.getSettings().displaySurface==='monitor')throw Error('Chỉ chọn cửa sổ.');
    track.addEventListener('ended',()=>{if(sessions.has(token))void api.stop(token);},{once:true});
    video.srcObject=stream;
    await video.play();
    if(!sessions.has(token))return;
    ui('status').textContent='Đang nhận diện cục bộ · '+sessions.size+' cửa sổ đã chọn';
    void tick(s);
  } catch {
    if(token!=null)await api.stop(token);
    ui('status').textContent='Chưa thể chia sẻ cửa sổ. Kiểm tra quyền hoặc chọn lại nguồn.';
  } finally {starting=false;updateButtons();}
}
ui('refresh').onclick=refresh;
ui('sources').onchange=updateButtons;
ui('start').onclick=()=>start(ui('sources').value);
ui('stop').onclick=()=>api.stop();
ui('login').onchange=async()=>{
  try{ui('login').checked=await api.login(ui('login').checked);}
  catch{ui('login').checked=false;ui('status').textContent='Chưa thể thay đổi mục đăng nhập.';}
};
api.onStop(stopped);
const applyTheme=theme=>{document.documentElement.dataset.theme=['light','dark'].includes(theme)?theme:'system';};
api.onTheme(applyTheme);
window.initializeMeetingAgent=async()=>{
  const state=await api.state();
  applyTheme(state.theme);
  ui('login').checked=state.login;
  if(state.portal){
    ui('status').textContent='Bấm Tìm cửa sổ rồi chọn cửa sổ Zalo hoặc Messenger riêng trong hộp thoại Linux. Quyền chia sẻ áp dụng cho phiên này.';
    return;
  }
  await refresh();
  for(const id of state.resume) await start(id);
};
