/* Proactive Day panel: calendar changes are the input; no chat prompt is needed. */
window.setupDay = function({getState, save, settled, replaceState, openModal, toast, escape, detail}) {
 const core=window.FriDayCore, native=window.friDesktop;
 let result={...core.analyze(getState()),mode:'local',status:'Đang kiểm tra lịch trên thiết bị.'};
 let timer, generation=0, busy=false, lastSignature='', applying=false;
 const visible=()=>result.cards.filter(c=>!(getState().settings.dayDismissed||[]).includes(c.id));
 const panel=()=>document.querySelector('#day-panel');
 function badge(){
  const count=visible().length;
  document.querySelectorAll('[data-day-count]').forEach(el=>{el.textContent=String(count);el.hidden=!count});
  document.querySelectorAll('[data-action="day"]').forEach(el=>el.setAttribute('aria-label',`Day · ${count} gợi ý`));
 }
 function paint(){
  const el=panel();if(!el)return;
  const s=getState(), cards=visible(), focused=document.activeElement?.dataset?.dayKey, optionsOpen=el.querySelector('.day-options')?.open;
  el.innerHTML=`<div class="day-summary"><span class="day-mode">${result.mode==='openai'?'Luna Max + Fri':'Trên thiết bị'}</span><span>${busy?'Đang cập nhật…':cards.length+' gợi ý cần xem'}</span></div>
   <p class="form-hint" role="status">${escape(result.status)}</p>
   <div class="day-suggestions">${cards.length?cards.map(c=>`<article class="day-suggestion" data-day-card="${escape(c.id)}">
    <span class="day-kind">${c.type==='deadline'?'GẦN ĐẾN HẠN':'TRÙNG LỊCH'}</span><h3>${escape(c.title)}</h3><p>${escape(c.body)}</p>
    ${c.move?`<div class="day-move"><span>${escape(c.move.fromTime)}</span><span aria-hidden="true">→</span><strong>${escape(c.move.time)}</strong><small>${escape(c.move.date)} · giữ nguyên thời lượng</small></div>`:''}
    <div class="day-evidence" aria-label="Lịch làm căn cứ">${c.evidenceIds.map(id=>{const t=s.tasks.find(t=>t.id===id);return t?`<button class="day-source" data-day-detail="${escape(id)}">${escape(t.title)}</button>`:''}).join('')}</div>
    <div class="day-card-actions">${c.move?`<button class="primary" data-day-apply="${escape(c.id)}" data-day-key="apply-${escape(c.id)}" ${applying?'disabled':''}>Áp dụng giờ mới</button>`:''}<button class="secondary" data-day-dismiss="${escape(c.id)}" data-day-key="dismiss-${escape(c.id)}">Bỏ qua</button></div>
   </article>`).join(''):`<div class="day-empty"><h3>Chưa có việc cần bạn xử lý.</h3><p>Day kiểm tra trùng lịch trong 7 ngày và deadline trong 24 giờ tới từ lịch Fri đã có.</p></div>`}</div>
   <details class="day-options" ${optionsOpen?'open':''}><summary>Cách Day hoạt động</summary><p>Chỉ đề xuất dời phiên Focus hoặc việc được đánh dấu “Có thể dời”, trong 09:00–18:00 cùng ngày và trước giờ kết thúc đã chọn cho Focus. Lịch nhập từ nguồn khác được giữ cố định. Khung trống chỉ phản ánh dữ liệu hiện có trong Fri.</p><p>Deadline chỉ được nhắc, không tự chia việc hoặc xếp thêm lịch. Day hoạt động khi Fri đang mở; không bật thông báo hệ điều hành.</p>
   <label class="day-cloud"><input id="day-cloud" type="checkbox" ${s.settings.dayOpenAIEnabled?'checked':''} ${native?'':'disabled'}><span>Dùng OpenAI Luna Max để sắp thứ tự gợi ý<small>Gửi tiêu đề, giờ và thông tin gợi ý liên quan tới OpenAI; không gửi ghi chú, địa điểm, ảnh hoặc nội dung nguồn. Có thể tắt bất cứ lúc nào.</small></span></label>
   <p class="form-hint">${native?'Điền key trong file cấu hình Day rồi bật tùy chọn trên. Khóa API chỉ được đọc ở tiến trình chính.':'Bản HTML kiểm tra lịch trên thiết bị. OpenAI được kết nối qua ứng dụng desktop.'}</p>
   <button class="secondary" data-day-reset>Hiện lại gợi ý đã bỏ qua</button></details>`;
  if(focused){const target=[...el.querySelectorAll('[data-day-key]')].find(n=>n.dataset.dayKey===focused);target?.focus()}
 }
 function publish(next){result=next;badge();paint()}
 function changed(force=false){
  const signature=core.fingerprint(getState())+':'+Boolean(getState().settings.dayOpenAIEnabled)+':'+JSON.stringify(getState().settings.dayDismissed||[])+':'+Math.floor(Date.now()/60000);
  if(!force&&signature===lastSignature){badge();return}
  lastSignature=signature;const token=++generation;clearTimeout(timer);busy=false;
  publish({...core.analyze(getState()),mode:'local',status:'Day kiểm tra trên dữ liệu lịch hiện có trong Fri.'});
  timer=setTimeout(()=>refresh(token),800);
 }
 async function refresh(token){
  if(!native)return;
  busy=true;paint();
  try{await settled();if(token!==generation)return;const next=await native.service('day-analyze');if(token===generation&&next.fingerprint===core.fingerprint(getState()))publish(next)}
  catch{if(token===generation)publish({...core.analyze(getState()),mode:'local',status:'Chưa kết nối được dịch vụ Day. Kiểm tra lịch trên thiết bị vẫn hoạt động.'})}
  finally{if(token===generation){busy=false;paint()}}
 }
 function open(){openModal('Day · Việc cần bạn xem','<section id="day-panel" aria-label="Gợi ý của Day"></section>','Từ lịch Fri đã có. Bạn quyết định thay đổi nào được áp dụng.');paint()}
 document.addEventListener('click',async e=>{
  const b=e.target.closest('[data-day-apply],[data-day-dismiss],[data-day-detail],[data-day-reset]');if(!b)return;
  if(b.hasAttribute('data-day-detail')){detail(b.dataset.dayDetail);return}
  if(b.hasAttribute('data-day-dismiss')){getState().settings.dayDismissed=[...new Set([...(getState().settings.dayDismissed||[]),b.dataset.dayDismiss])].slice(-100);save();changed(true);return}
  if(b.hasAttribute('data-day-reset')){getState().settings.dayDismissed=[];save();changed(true);return}
  if(applying)return;
  const request={id:b.dataset.dayApply,fingerprint:result.fingerprint};applying=true;paint();
  try{
   await settled();
   if(native){await native.service('day-apply',request);await settled();const payload=await native.loadState();replaceState(payload.state)}
   else {
    const saved=JSON.parse(localStorage.getItem('fri-liquid-preview-v1'));
    if(saved&&core.fingerprint(saved)!==core.fingerprint(getState())){replaceState(saved);throw Error('Lịch đã đổi ở cửa sổ khác. Hãy xem gợi ý mới.')}
    const before=getState(),next=core.applyMove(before,request);replaceState(next);
    if(!save()){replaceState(before);throw Error('Chưa lưu được thay đổi. Hãy thử lại.')}
   }
   toast('Đã dời việc trong lịch Fri. Nguồn lịch bên ngoài không bị thay đổi.');changed(true);
  }catch(e){toast(e.message||'Lịch đã thay đổi. Hãy xem gợi ý mới.');changed(true)}
  finally{applying=false;paint()}
 });
 document.addEventListener('change',e=>{if(e.target.id!=='day-cloud')return;getState().settings.dayOpenAIEnabled=e.target.checked;save();changed(true)});
 document.addEventListener('visibilitychange',()=>{if(!document.hidden)changed(true)});
 window.addEventListener('focus',()=>changed());
 setInterval(()=>{if(!document.hidden)changed()},60000);
 changed(true);
 return {open,changed};
};
