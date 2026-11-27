(()=>{
 const dialog=document.createElement('dialog');dialog.id='time-picker';dialog.setAttribute('aria-labelledby','time-picker-title');
 dialog.innerHTML='<header><h2 id="time-picker-title">Choose time</h2><button type="button" class="icon-button" aria-label="Close time picker">×</button></header><div class="time-wheels"><div class="wheel-selection" aria-hidden="true"></div></div><button type="button" class="primary time-confirm">Confirm</button>';
 document.body.append(dialog);
 let input=null,returnTo=null,values=[9,0,0],generation=0,scrollTimers=[];
 const columns=[{label:'Hour',length:12,offset:1},{label:'Minute',length:60,offset:0},{label:'Period',length:2,offset:0}];
 const wheels=columns.map((c,col)=>{
  const box=document.createElement('div');box.className='time-wheel';box.tabIndex=0;box.setAttribute('role','listbox');box.setAttribute('aria-label',c.label);
  for(let i=0;i<c.length;i++){const option=document.createElement('div');option.id=`time-option-${col}-${i}`;option.className='time-option';option.setAttribute('role','option');option.textContent=col===2?['AM','PM'][i]:String(i+c.offset).padStart(2,'0');option.onclick=()=>select(col,i+c.offset,true);box.append(option)}
  box.onkeydown=e=>{if(e.isComposing||e.altKey||e.ctrlKey||e.metaKey)return;const current=values[col]-c.offset;let next;
   if(e.key==='ArrowUp')next=(current-1+c.length)%c.length;else if(e.key==='ArrowDown')next=(current+1)%c.length;else if(e.key==='Home')next=0;else if(e.key==='End')next=c.length-1;else if(e.key==='PageUp')next=Math.max(0,current-5);else if(e.key==='PageDown')next=Math.min(c.length-1,current+5);
   else if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();wheels[(col+(e.key==='ArrowRight'?1:2))%3].focus();return}
   else if(col===2&&/^[ap]$/i.test(e.key))next=e.key.toLowerCase()==='a'?0:1;
   else if(e.key==='Enter'){e.preventDefault();confirm();return}
   if(next!==undefined){e.preventDefault();select(col,next+c.offset,true)}
  };
  box.addEventListener('scroll',()=>{clearTimeout(scrollTimers[col]);const run=generation;scrollTimers[col]=setTimeout(()=>{if(dialog.open&&generation===run){const index=Math.max(0,Math.min(c.length-1,Math.round(box.scrollTop/44)));select(col,index+c.offset,false)}},90)});
  dialog.querySelector('.time-wheels').append(box);return box;
 });
 function select(col,value,scroll){values[col]=value;const box=wheels[col],index=value-columns[col].offset;[...box.children].forEach((o,i)=>o.setAttribute('aria-selected',String(i===index)));box.setAttribute('aria-activedescendant',box.children[index].id);if(scroll)box.scrollTop=index*44}
 function label(value){if(!value)return 'Choose time';const [h,m]=value.split(':').map(Number);return `${h%12||12}:${String(m).padStart(2,'0')} ${h<12?'AM':'PM'}`}
 function close(){generation++;scrollTimers.forEach(clearTimeout);dialog.close();returnTo?.focus()}
 function confirm(){if(!input?.isConnected){close();return}wheels.forEach((box,i)=>select(i,Math.max(0,Math.min(columns[i].length-1,Math.round(box.scrollTop/44)))+columns[i].offset,false));const hour=values[0]%12+values[2]*12;input.value=`${String(hour).padStart(2,'0')}:${String(values[1]).padStart(2,'0')}`;input.dispatchEvent(new Event('input',{bubbles:true}));input.dispatchEvent(new Event('change',{bubbles:true}));close()}
 dialog.querySelector('header button').onclick=close;dialog.querySelector('.time-confirm').onclick=confirm;
 dialog.addEventListener('cancel',e=>{e.preventDefault();close()});
 dialog.addEventListener('keydown',e=>{if(e.key==='Tab'){const stops=[dialog.querySelector('header button'),...wheels,dialog.querySelector('.time-confirm')],first=stops[0],last=stops.at(-1);if(e.shiftKey&&e.target===first){e.preventDefault();last.focus()}else if(!e.shiftKey&&e.target===last){e.preventDefault();first.focus()}}e.stopPropagation()});
 function decorate(root=document){root.querySelectorAll('input[type=time]:not([data-wheel-time])').forEach(el=>{
   el.dataset.wheelTime='true';el.tabIndex=-1;el.classList.add('time-value');el.setAttribute('aria-hidden','true');
   const button=document.createElement('button');button.type='button';button.className='time-field';button.dataset.timeName=el.name;button.setAttribute('aria-haspopup','dialog');
   const prefix=el.closest('label')?.querySelector('span')?.textContent||'Time';
   const update=()=>{button.textContent=label(el.value);button.setAttribute('aria-label',prefix+': '+label(el.value));button.disabled=el.disabled};update();el.addEventListener('input',update);el.addEventListener('change',update);
   if(el.autofocus){el.autofocus=false;button.autofocus=true}
   el.addEventListener('invalid',e=>{e.preventDefault();button.focus();button.setAttribute('aria-invalid','true')});
   button.onclick=()=>{input=el;returnTo=button;generation++;scrollTimers.forEach(clearTimeout);const now=new Date(),[h,m]=el.value?el.value.split(':').map(Number):[now.getHours(),now.getMinutes()];dialog.showModal();select(0,h%12||12,true);select(1,m,true);select(2,h<12?0:1,true);wheels[0].focus();button.removeAttribute('aria-invalid')};
   el.after(button);
  })}
 window.FriTimePicker={decorate,sync(root=document){root.querySelectorAll('[data-wheel-time]').forEach(e=>e.dispatchEvent(new Event('input',{bubbles:true})))}};
})();
