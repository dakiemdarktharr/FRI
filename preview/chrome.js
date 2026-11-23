(()=>{
  const $=s=>document.querySelector(s), root=document.documentElement, bridge=window.friDesktop;
  const platform=bridge?.platform||(/Mac/i.test(navigator.platform)?'darwin':'win32');
  root.dataset.platform=platform;
  if(bridge){root.classList.add('native-app');root.dataset.material=bridge.material;}
  const popover=$('#app-menu-popover');
  let trigger=null;
  const menus={
    new:[['One-time deadline','deadline','A single due date and time'],['Schedule','schedule','An appointment with a duration']],
    file:[['Import plans from files or text','intake'],['Find time for a task','focus'],['Find time together · Local preview','together'],null,['Create FRI widget on desktop','desktop-widget'],null,['New deadline','deadline'],['New schedule','schedule'],null,['Export calendar backup…','export'],['Restore calendar backup…','import'],null,['Settings','settings','Ctrl/⌘ ,'],['Close window','close']],
    edit:[['Undo last deletion','undo'],['Search appointments','search','Ctrl/⌘ F'],['Edit or delete appointments','manage']],
    view:[['My day','day'],['Month','month'],['Year','year'],null,['Toggle sidebar','sidebar','Ctrl/⌘ B'],['Toggle full screen','fullscreen']],
    help:[['Keyboard shortcuts','shortcuts'],['Check for updates…','updates'],['About FRI','about']]
  };
  const updateButton=$('#fri-update'), updateAnnouncement=$('#fri-update-status');
  let updateState=null, updateBusy=false, lastUpdatePhase='';
  function updateToast(message){$('#toast').textContent=message;$('#toast').hidden=false;}
  function renderUpdate(next){
    if(!next||typeof next.phase!=='string')return;updateState=next;
    const labels={checking:'Checking…',available:'Update v'+next.latestVersion,manual:'Download v'+next.latestVersion,downloading:'Downloading '+Math.floor(next.percent||0)+'%',ready:'Restart to update',installing:'Preparing restart…',error:'Retry update'};
    updateButton.hidden=!bridge||!labels[next.phase];updateButton.dataset.phase=next.phase;
    updateButton.disabled=updateBusy||['checking','downloading','installing'].includes(next.phase);
    updateButton.querySelector('.fri-update-label').textContent=labels[next.phase]||'Check for updates';
    updateButton.title=next.message||labels[next.phase]||'';
    updateButton.setAttribute('aria-label',(labels[next.phase]||'Check for updates')+(next.message?'. '+next.message:''));
    if(next.phase!==lastUpdatePhase){updateAnnouncement.textContent=next.phase==='downloading'?'Downloading the Fri update':next.message||labels[next.phase]||'';lastUpdatePhase=next.phase;}
  }
  async function updateAction(action){
    if(!bridge?.updateAction||updateBusy)return;updateBusy=true;if(updateState)renderUpdate(updateState);
    try{
      if(action==='install'){
        if(typeof window.FRI_PREVIEW?.flush!=='function')throw Error('Not ready');
        await window.FRI_PREVIEW.flush();
      }
      const next=await bridge.updateAction(action);renderUpdate(next);
      if(['current','unavailable','error'].includes(next.phase)||(next.phase==='ready'&&action==='install'))updateToast(next.message);
    }catch{updateToast(action==='install'?'Your latest changes are not saved yet. Keep Fri open and retry.':'Could not check for an update. Try again later.');}
    finally{updateBusy=false;if(updateState)renderUpdate(updateState);}
  }
  if(bridge?.updateAction){
    const unsubscribe=bridge.onUpdateState(renderUpdate);
    bridge.updateAction('status').then(renderUpdate).catch(()=>{});
    updateButton.addEventListener('click',()=>{const actions={available:'download',manual:'open-releases',ready:'install',error:'check'};const action=actions[updateState?.phase];if(action)void updateAction(action)});
    window.addEventListener('beforeunload',()=>unsubscribe?.(),{once:true});
  }
  function closeMenu(focus=false){popover.hidden=true;trigger?.setAttribute('aria-expanded','false');if(focus)trigger?.focus();trigger=null;}
  async function command(action){
    if(['close','fullscreen'].includes(action)){
      if(bridge){await bridge.windowAction(action);return;}
      if(action==='fullscreen'){if(document.fullscreenElement)await document.exitFullscreen();else await $('#app').requestFullscreen?.();}
      else $('#toast').textContent='Window controls are available in the desktop app.', $('#toast').hidden=false;
      return;
    }
    if(action==='updates'){
      if(bridge)await updateAction('check');
      else {$('#toast').textContent='Install the FRI desktop app to check for updates.';$('#toast').hidden=false;}
      return;
    }
    window.FRI_COMMAND?.(action);
  }
  function showMenu(button){
    const wasOpen=trigger===button&&!popover.hidden;closeMenu();if(wasOpen)return;
    trigger=button;button.setAttribute('aria-expanded','true');
    popover.innerHTML=menus[button.dataset.menu].map(item=>item?`<button role="menuitem" data-command="${item[1]}"><span>${item[0]}</span>${item[2]?`<small>${item[2]}</small>`:''}</button>`:'<hr role="separator">').join('');
    popover.hidden=false;
    const r=button.getBoundingClientRect();popover.style.left=Math.max(8,Math.min(r.left,innerWidth-popover.offsetWidth-8))+'px';popover.style.top=Math.min(r.bottom+6,innerHeight-popover.offsetHeight-8)+'px';
    popover.querySelector('button')?.focus();
  }
  document.addEventListener('click',async e=>{
    const menu=e.target.closest('[data-menu]');if(menu){showMenu(menu);return;}
    const item=e.target.closest('[data-command]');if(item){const action=item.dataset.command;closeMenu(true);await command(action);return;}
    if(!popover.contains(e.target))closeMenu();
    const control=e.target.closest('[data-window]');if(control){if(bridge)await bridge.windowAction(control.dataset.window);else{ $('#toast').textContent='Window controls are available in the desktop app.';$('#toast').hidden=false;}}
  });
  document.addEventListener('keydown',e=>{
    if(e.key==='Escape'&&!popover.hidden){e.preventDefault();closeMenu(true);return;}
    if(!popover.hidden&&['ArrowDown','ArrowUp','Home','End'].includes(e.key)){
      e.preventDefault();const items=[...popover.querySelectorAll('button')],i=items.indexOf(document.activeElement);items[e.key==='Home'?0:e.key==='End'?items.length-1:(i+(e.key==='ArrowDown'?1:-1)+items.length)%items.length].focus();return;
    }
    if(e.key==='Tab'&&!popover.hidden)closeMenu();
    if(!(e.ctrlKey||e.metaKey)||e.altKey)return;
    const actions={f:'search',b:'sidebar',',':'settings',n:'schedule'};
    if(actions[e.key.toLowerCase()]){e.preventDefault();closeMenu();command(actions[e.key.toLowerCase()]);}
  });
  document.querySelector('.app-titlebar').addEventListener('dblclick',e=>{if(!e.target.closest('button')&&bridge)bridge.windowAction('maximize');});
  window.addEventListener('resize',()=>closeMenu());
  bridge?.onCommand(command);
  bridge?.onWindowState(s=>{
    const b=$('[data-window=maximize]');b.setAttribute('aria-label',s.maximized?'Restore window':'Maximize window');
    root.classList.toggle('window-maximized',s.maximized);root.classList.toggle('window-unfocused',!s.focused);
  });
})();
