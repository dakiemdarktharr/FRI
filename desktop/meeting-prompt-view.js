meetingPrompt.onData(({item,theme})=>{document.body.classList.toggle('dark',theme==='dark');document.getElementById('name').textContent=item.title;document.getElementById('time').textContent=[item.date||'Choose a date',item.time||item.timeHint||item.relativeTime||'Choose a time'].join(' · ');});
document.getElementById('review').onclick=()=>meetingPrompt.answer(0);document.getElementById('dismiss').onclick=()=>meetingPrompt.answer(1);
document.addEventListener('keydown',e=>{if(e.key==='Escape')meetingPrompt.answer(1)});
