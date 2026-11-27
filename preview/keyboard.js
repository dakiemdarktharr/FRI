// Shared by the standalone preview, browser app and desktop renderer.
(()=>{
 const $=(s,r=document)=>r.querySelector(s),all=(s,r=document)=>[...r.querySelectorAll(s)];
 const visible=e=>!!e&&!e.closest('[inert]')&&e.getClientRects().length>0&&getComputedStyle(e).visibility!=='hidden';
 const editable=e=>!!e?.closest('input,textarea,select,[contenteditable]:not([contenteditable=false]),[role=textbox]');
 const identity=e=>{
  if(!e||e===document.body)return null;
  if(e.id)return '#'+CSS.escape(e.id);
  const attributes=['data-action','data-id','data-date','data-widget','data-view','data-menu','data-source-id','data-library-id','data-edit-import','data-native','name'];
  const parts=attributes.filter(a=>e.hasAttribute(a)).map(a=>`[${a}="${CSS.escape(e.getAttribute(a))}"]`);
  return parts.length?e.tagName.toLowerCase()+parts.join(''):null;
 };
 function remember(){const el=document.activeElement;return {el,selector:identity(el),inModal:!!el?.closest('#modal'),inTabs:!!el?.closest('#tabs'),feedIndex:all('.feed-card').indexOf(el?.closest('.feed-card')),inWidgets:!!el?.closest('.widget-rail')}}
 function restore(mark,fallback){
  if(!mark)return;
  const root=mark.inModal&&$('#modal')?.open?$('#modal'):document;
  let target=mark.el?.isConnected&&visible(mark.el)?mark.el:mark.selector?all(mark.selector,root).find(visible):null;
  if(!target&&mark.feedIndex>=0){const cards=all('.feed-card');target=cards[Math.min(mark.feedIndex,cards.length-1)]?.querySelector(mark.el.matches('.feed-check')?'.feed-check':'.feed-open')}
  if(!target)target=fallback||(mark.inTabs?$('#tabs .tab-select[aria-pressed=true]'):mark.inWidgets?$('.add-widget'):$('#calendar-content'));
  if(visible(target))target.focus({preventScroll:true});
 }
 function preserve(mark){if(mark?.el&&!mark.el.isConnected&&(!$('#modal')?.open||mark.inModal))restore(mark)}
 function syncSidebar(){
  const app=$('#app'),sidebar=$('#sidebar'),mobile=innerWidth<=820,open=mobile?app.classList.contains('sidebar-open'):!app.classList.contains('sidebar-collapsed');
  sidebar.inert=!open;
  all('[data-action=sidebar]').forEach(b=>{b.setAttribute('aria-expanded',String(open));b.setAttribute('aria-controls','sidebar')});
  $('#main').inert=mobile&&open;
  return {mobile,open};
 }
 function shortcutHelp(){return `<dl class="shortcut-list">${[
  ['New plan','N'],['New schedule','Ctrl / ⌘ + N'],['Search','/ or Ctrl / ⌘ + K / F'],['Settings','Ctrl / ⌘ + ,'],['Toggle sidebar','Ctrl / ⌘ + B'],['Move between areas','F6 · Shift + F6'],['Today','T'],['Feed / Week / Month / Year','1 / 2 / 3 / 4'],['Add ready plans','R'],['Help','?'],['Save the current form','Ctrl / ⌘ + Enter'],['Move within a calendar','Arrow keys · Home / End'],['Previous / next month','Page Up / Page Down'],['Previous / next year','Shift + Page Up / Page Down'],['Move between plans or results','↑ / ↓ · Home / End'],['Move between day tabs','← / → · Home / End'],['Close focused day tab','Delete'],['Close or go back','Escape']
 ].map(([label,key])=>`<div><dt>${label}</dt><dd><kbd>${key}</kbd></dd></div>`).join('')}</dl><p class="form-hint">Single-letter shortcuts pause while you type. Enter opens the focused item; Space activates its button. On desktop widgets, arrow keys move or resize from the focused handle; Shift uses larger steps.</p>`}
 window.FriFocus={remember,restore,preserve,syncSidebar,editable,visible,shortcutHelp};
 window.setupKeyboard=ctx=>{
  const modal=$('#modal');
  syncSidebar();new MutationObserver(syncSidebar).observe($('#app'),{attributes:true,attributeFilter:['class']});
  window.addEventListener('resize',()=>{const was=document.activeElement;syncSidebar();if(was?.closest('[inert]'))$('.titlebar-toggle').focus()});
  $('#skip-calendar').onclick=e=>{e.preventDefault();if(innerWidth<=820)$('#app').classList.remove('sidebar-open');syncSidebar();$('#calendar-content').focus()};
  document.addEventListener('keydown',e=>{
   if(e.defaultPrevented||e.isComposing||e.keyCode===229)return;
   if(!$('#app-menu-popover').hidden)return;
   const target=e.target,typing=editable(target),mod=e.ctrlKey||e.metaKey;
   if(e.key==='Escape'){
    if(modal.open)return; // Native cancel event runs the unsaved-form guard.
    const sidebar=syncSidebar();if(sidebar.mobile&&sidebar.open){e.preventDefault();$('#app').classList.remove('sidebar-open');syncSidebar();$('.titlebar-toggle').focus()}
    $('#hover-preview').hidden=true;return;
   }
   if(modal.open&&e.key==='Tab'){
    const stops=all('button:not(:disabled),a[href],input:not(:disabled),select:not(:disabled),textarea:not(:disabled),summary,[tabindex="0"]',modal).filter(visible);
    const first=stops[0],last=stops.at(-1);
    if(e.shiftKey&&(target===first||!stops.includes(target))){e.preventDefault();last?.focus()}
    else if(!e.shiftKey&&target===last){e.preventDefault();first?.focus()}
    return;
   }
   if(modal.open&&mod&&e.key==='Enter'&&!e.repeat){
    const form=target.closest('form')||$('form',modal),submit=form&&$('button[type=submit].primary,button[value=done],button.primary:not([type=button])',form);
    if(form&&submit&&!submit.disabled){e.preventDefault();form.requestSubmit(submit)}return;
   }
   if(target.id==='search-input'&&['ArrowDown','Enter'].includes(e.key)){
    const result=$('#search-results button');if(result){e.preventDefault();if(e.key==='Enter')result.click();else result.focus()}return;
   }
   if(typing)return;
   const result=target.closest('#search-results button');
   if(result&&['ArrowDown','ArrowUp','Home','End'].includes(e.key)){
    e.preventDefault();const items=all('#search-results button'),i=items.indexOf(result);
    if(e.key==='ArrowUp'&&i===0)$('#search-input').focus();else items[e.key==='Home'?0:e.key==='End'?items.length-1:Math.max(0,Math.min(items.length-1,i+(e.key==='ArrowDown'?1:-1)))].focus();return;
   }
   const cell=target.closest('.day-cell');
   if(cell&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End','PageUp','PageDown'].includes(e.key)){
    e.preventDefault();let date=new Date(cell.dataset.date+'T12:00:00');
    if(e.key.startsWith('Page')){const day=date.getDate();date.setDate(1);date.setMonth(date.getMonth()+(e.key==='PageDown'?1:-1)*(e.shiftKey?12:1));date.setDate(Math.min(day,new Date(date.getFullYear(),date.getMonth()+1,0).getDate()))}
    else date.setDate(date.getDate()+({ArrowLeft:-1,ArrowRight:1,ArrowUp:-7,ArrowDown:7,Home:-date.getDay(),End:6-date.getDay()}[e.key]));
    ctx.calendarFocus(date,modal.open);return;
   }
   const tile=target.closest('.month-tile');
   if(tile&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End'].includes(e.key)){
    e.preventDefault();const tiles=all('.month-tile'),i=tiles.indexOf(tile),cols=getComputedStyle($('.year-grid')).gridTemplateColumns.split(' ').length;
    const next=e.key==='Home'?0:e.key==='End'?11:Math.max(0,Math.min(11,i+({ArrowLeft:-1,ArrowRight:1,ArrowUp:-cols,ArrowDown:cols}[e.key])));tiles[next].focus();return;
   }
   if(modal.open)return;
   const tab=target.closest('.tab-select');
   if(tab&&['ArrowLeft','ArrowRight','Home','End','Delete'].includes(e.key)){
    e.preventDefault();if(e.key==='Delete'){tab.parentElement.querySelector('.tab-close').click();return}
    const tabs=all('.tab-select'),i=tabs.indexOf(tab),next=e.key==='Home'?0:e.key==='End'?tabs.length-1:(i+(e.key==='ArrowRight'?1:-1)+tabs.length)%tabs.length;tabs[next].click();$('#tabs .tab-select[aria-pressed=true]').focus();return;
   }
   const card=target.closest('.feed-card');
   if(card&&!mod&&!e.altKey&&['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Home','End'].includes(e.key)){
    e.preventDefault();const cards=all('.feed-card'),i=cards.indexOf(card),next=e.key==='Home'?0:e.key==='End'?cards.length-1:Math.max(0,Math.min(cards.length-1,i+(e.key==='ArrowDown'?1:e.key==='ArrowUp'?-1:0)));
    cards[next].querySelector(e.key==='ArrowRight'?'.feed-check':e.key==='ArrowLeft'?'.feed-open':target.matches('.feed-check')?'.feed-check':'.feed-open').focus();return;
   }
   if(e.key==='F6'){
    e.preventDefault();const regions=[$('.app-menus'),$('#sidebar'),$('#tabs'),$('#calendar-content'),$('.widget-rail')].filter(visible).filter(r=>!r.inert),i=regions.findIndex(r=>r.contains(target)),next=(i+(e.shiftKey?-1:1)+regions.length)%regions.length;
    const r=regions[next];(all('button:not(:disabled),[tabindex="0"]',r).find(visible)||r).focus();return;
   }
   if(e.altKey||e.repeat||(!mod&&!ctx.singleKeys()))return;
   const key=e.key.toLowerCase();
   const action=mod?({n:'schedule',k:'search',f:'search',b:'sidebar',',':'settings'}[key]):({n:'new','/':'search','?':'shortcuts',t:'today','1':'day','2':'week','3':'month','4':'year',r:'refresh'}[key]);
   if(action){e.preventDefault();if(action==='new')$('[data-menu=new]').click();else ctx.command(action)}
  });
 };
})();
