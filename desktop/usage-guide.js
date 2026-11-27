'use strict';
const ui=id=>document.getElementById(id),reviewing=location.hash==='#review';
let busy=false;
ui('skip').textContent=reviewing?'Back to calendar':'Explore Fri';
ui('try').onclick=()=>{
 const plan=window.FRIMeetingAgent.proposeDraft('Tomorrow at 7 pm, coffee?');
 if(!plan){ui('error').textContent='The sample could not be read. You can create a plan instead.';return;}
 ui('when').textContent=new Date(plan.date+'T'+plan.time).toLocaleString('en',{weekday:'long',hour:'numeric',minute:'2-digit'});
 ui('welcome').hidden=true;ui('result').hidden=false;ui('result').querySelector('h1').focus();
};
ui('again').onclick=()=>{ui('welcome').hidden=false;ui('result').hidden=true;ui('try').focus();};
async function finish(action){
 if(busy)return;busy=true;document.querySelectorAll('button').forEach(b=>b.disabled=true);
 try{await window.friDesktop.finishUsageGuide(action);if(reviewing)window.close();}
 catch{busy=false;document.querySelectorAll('button').forEach(b=>b.disabled=false);ui('error').textContent='Could not open your calendar. Try again.';}
}
ui('skip').onclick=()=>finish('explore');ui('new').onclick=()=>finish('schedule');ui('review').onclick=()=>finish('sample');
document.addEventListener('keydown',e=>{if(e.key==='Escape')finish('explore');});
