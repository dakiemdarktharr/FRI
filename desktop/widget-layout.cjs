'use strict';
const intersects=(a,b)=>a.x<b.x+b.width&&a.x+a.width>b.x&&a.y<b.y+b.height&&a.y+a.height>b.y;
function relocateIcons(icons,widgets,area,cell={width:86,height:96}){
 const occupied=icons.filter(i=>!widgets.some(w=>intersects({...i,...cell},w))).map(i=>({...i,...cell})),moves=[];
 for(const icon of icons){if(!widgets.some(w=>intersects({...icon,...cell},w)))continue;const candidates=[];
  for(let y=area.y;y+cell.height<=area.y+area.height;y+=cell.height)for(let x=area.x;x+cell.width<=area.x+area.width;x+=cell.width){const r={x,y,...cell};if(!widgets.some(w=>intersects(r,w))&&!occupied.some(o=>intersects(r,o)))candidates.push(r)}
  candidates.sort((a,b)=>Math.hypot(a.x-icon.x,a.y-icon.y)-Math.hypot(b.x-icon.x,b.y-icon.y));if(candidates[0]){const to=candidates[0];moves.push({id:icon.id,from:{x:icon.x,y:icon.y},to:{x:to.x,y:to.y}});occupied.push(to)}
 }
 return moves;
}
function todayTasks(state,now=new Date()){
 const key=[now.getFullYear(),String(now.getMonth()+1).padStart(2,'0'),String(now.getDate()).padStart(2,'0')].join('-');
 const tasks=(state?.tasks||[]).filter(t=>t.date===key).sort((a,b)=>a.time.localeCompare(b.time)),pending=tasks.filter(t=>!t.done),minutes=now.getHours()*60+now.getMinutes();
 const current=pending.find(t=>{const [h,m]=t.time.split(':').map(Number),start=h*60+m;return start<=minutes&&start+t.duration>minutes})||pending[0];
 return {key,tasks,current,pending,completed:tasks.filter(t=>t.done).length};
}
module.exports={relocateIcons,intersects,todayTasks};
