'use strict';
const map=L.map('map',{zoomControl:true,scrollWheelZoom:true}).setView([0,0],2);
const tiles=L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors',updateWhenIdle:true,keepBuffer:1});
let marker=null,loaded=false;
tiles.on('tileerror',()=>{if(!loaded)document.querySelector('#status').textContent='Map unavailable. Check your connection or use Explore places.'});
tiles.on('tileload',()=>{loaded=true;document.querySelector('#status').textContent=''});
function show(place){if(!place)return;document.querySelector('#city').textContent=place.name;const p=[place.latitude,place.longitude];map.setView(p,13);if(!map.hasLayer(tiles))tiles.addTo(map);if(marker)marker.setLatLng(p);else marker=L.circleMarker(p,{radius:6,color:'#955251',fillOpacity:1}).addTo(map);document.querySelector('#places').href='https://www.openstreetmap.org/#map=14/'+p[0]+'/'+p[1]}
friMap.onPlace(show);friMap.read().then(show).catch(()=>document.querySelector('#status').textContent='Could not open this location. Reconnect Maps in FRI.');
