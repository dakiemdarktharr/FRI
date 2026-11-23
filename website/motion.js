(() => {
  'use strict';
  const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
  const reduced=matchMedia('(prefers-reduced-motion: reduce)'),evidence=window.FRI_WEBSITE.evidence,canvas=$('#sea');
  let resizeSea=()=>{},drawSea=null,drawTime=-1,routeBusy=false,routeTimer,activeRoute='home',lastScramble='';
  const word=$('#hero-word'),mark=$('#hero-mark'),title=$('#hero-title');
  const slogans=['Fri.','Make time\nfor your life.','[mark]'],glyphs='FRI./:;+=?#%';
  function scramble(t){
    const index=Math.floor(t/1.6)%3,phase=t%1.6,next=slogans[(index+1)%3],text=slogans[index],changing=phase>=1.3,p=changing?(phase-1.3)/.3:0;
    title.classList.toggle('scrambling',changing);title.classList.toggle('mission',text.includes('\n')||(changing&&next.includes('\n')));
    evidence.scramble={index,phase:Math.round(phase*1000),changing,text:changing?'transition':text};
    if(!changing&&text==='[mark]'){word.hidden=true;mark.hidden=false;lastScramble='mark';return}
    word.hidden=false;mark.hidden=true;
    const target=changing?(next==='[mark]'?'FRI':next):text,source=text==='[mark]'?'FRI':text;
    let display=target;
    if(changing){const max=Math.max(source.length,target.length);display=Array.from({length:max},(_,i)=>{if(target[i]==='\n')return '\n';if(i/max<p*.95)return target[i]||'';return glyphs[Math.floor((t*83+i*17)%glyphs.length)]}).join('')}
    if(lastScramble!==display){word.textContent=display;lastScramble=display}
  }
  const logo=$('.brand .pole').innerHTML;
  const tiles=Array.from({length:36},(_,i)=>{const tile=document.createElement('div');tile.className='gallery-tile '+(i%2?'portrait':'');tile.innerHTML=i%2?'<span class="pole">'+logo+'</span>':'<span class="wordmark">fri.</span>';$('#footer-gallery').append(tile);return tile});
  let safe=[];
  function measureFooter(){const f=$('#footer').getBoundingClientRect();safe=$$('.footer-safe').map(e=>{const r=e.getBoundingClientRect();return{x:r.left-f.left,y:r.top-f.top,w:r.width,h:r.height}})}
  function gallery(t){
    const w=$('#footer').clientWidth,h=$('#footer').clientHeight,columns=Math.max(4,Math.ceil((w+400)/210)),rows=Math.ceil((h+400)/185),periodX=columns*210,periodY=rows*185;
    tiles.forEach((tile,i)=>{
      const col=i%columns,row=Math.floor(i/columns),x=((col*210+t*20+row*65)%periodX)-200,y=((row*185+t*11)%periodY)-180;
      tile.style.transform='translate('+x+'px,'+y+'px) rotate(-14deg)';
      const b={x:x-100,y:y-100,w:180,h:180},overlap=safe.some(r=>b.x<r.x+r.w+20&&b.x+b.w>r.x-20&&b.y<r.y+r.h+16&&b.y+b.h>r.y-16);
      tile.classList.toggle('muted',overlap);tile.style.opacity=overlap?'.12':'.55';
    });
  }
  function footerReveal(){const r=$('.footer-reveal').getBoundingClientRect(),progress=Math.max(0,Math.min(1,(innerHeight-r.top)/Math.min(innerHeight,r.height)));$('#footer').style.opacity=String(.15+.85*progress)}
  measureFooter();window.addEventListener('resize',measureFooter);window.addEventListener('scroll',footerReveal,{passive:true});document.fonts.ready.then(measureFooter);
  function showRoute(route,push=false){
    activeRoute=route;const pricing=route==='pricing';$('#home-page').hidden=pricing;$('#pricing-page').hidden=!pricing;
    document.body.classList.toggle('pricing-view',pricing);$('.topbar .nav-link[data-route]').setAttribute('aria-current',pricing?'page':'false');
    $('.topbar .brand').setAttribute('href',location.protocol==='file:'?'#home':'/');document.title=pricing?'Pricing — Fri.':'Fri. — Less noise. More life.';
    if(push){const dest=location.protocol==='file:'?(pricing?'#pricing':'#home'):(pricing?'/pricing/':'/');history.pushState({route},'',dest)}
    scrollTo(0,0);if(!pricing)resizeSea();measureFooter();footerReveal();(pricing?$('#pricing-title'):$('#hero-title')).focus({preventScroll:true});evidence.route=route;
  }
  async function navigate(route,push=true){
    if(routeBusy||route===activeRoute)return;routeBusy=true;const curtains=$('#curtains');curtains.classList.add('active');requestAnimationFrame(()=>curtains.classList.add('closed'));
    const delay=reduced.matches?0:340;
    routeTimer=setTimeout(()=>{showRoute(route,push);setTimeout(()=>{curtains.classList.remove('closed');setTimeout(()=>{curtains.classList.remove('active');routeBusy=false},delay)},reduced.matches?0:80)},delay);
  }
  $$('[data-route]').forEach(a=>a.addEventListener('click',e=>{if(e.ctrlKey||e.metaKey||e.shiftKey)return;e.preventDefault();navigate(a.dataset.route)}));
  $('.topbar .brand').addEventListener('click',e=>{if(activeRoute==='pricing'){e.preventDefault();navigate('home')}});
  $('.topbar a[href="#what"]').addEventListener('click',e=>{if(activeRoute==='pricing'){e.preventDefault();navigate('home');setTimeout(()=>$('#what').scrollIntoView({behavior:reduced.matches?'instant':'smooth'}),reduced.matches?50:800)}});
  window.addEventListener('popstate',()=>{clearTimeout(routeTimer);$('#curtains').classList.remove('active','closed');routeBusy=false;showRoute(location.pathname.includes('/pricing')||location.hash==='#pricing'?'pricing':'home')});
  $$('.plan-card').forEach(card=>{card.addEventListener('pointermove',e=>{if(reduced.matches||e.pointerType==='touch')return;const r=card.getBoundingClientRect(),x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;card.style.transform='rotateX('+(-y*10)+'deg) rotateY('+(x*12)+'deg)'});card.addEventListener('pointerleave',()=>card.style.transform='');card.addEventListener('blur',()=>card.style.transform='',true)});
  function setupSea(){
    try{
      const gl=canvas.getContext('webgl',{alpha:false,antialias:false,powerPreference:'low-power',preserveDrawingBuffer:true});if(!gl)throw Error('WebGL unavailable');
      const vertex='attribute vec2 p;varying vec2 uv;void main(){uv=p*.5+.5;gl_Position=vec4(p,0.,1.);}';
      const fragment=[
        'precision highp float;varying vec2 uv;uniform sampler2D footage;uniform vec2 resolution;uniform float pixelRatio;uniform float aspect;',
        'void main(){float pitch=3.1*pixelRatio;mat2 rotation=mat2(.7071,-.7071,.7071,.7071);mat2 inverseRotation=mat2(.7071,.7071,-.7071,.7071);vec2 grid=rotation*gl_FragCoord.xy/pitch;vec2 center=inverseRotation*(floor(grid)+.5)*pitch/resolution;vec2 q=vec2(center.x,1.-center.y);float screen=resolution.x/resolution.y;if(screen>aspect)q.y=(q.y-.5)*aspect/screen+.5;else q.x=(q.x-.5)*screen/aspect+.5;',
        'vec3 video=texture2D(footage,q).rgb;float light=clamp((dot(video,vec3(.2126,.7152,.0722))-.06)*1.16,.03,.985);vec2 point=fract(grid)-.5;float radius=sqrt(min(light,1.-light)/3.14159);float dotMask=1.-smoothstep(radius-.065,radius+.065,length(point));float tone=light>.5?1.-dotMask:dotMask;vec3 paper=vec3(.98,.963,.944),ink=vec3(.24,.11,.12);gl_FragColor=vec4(mix(ink,paper,tone),1.);}',
      ].join('\n');
      function compile(type,src){const shader=gl.createShader(type);gl.shaderSource(shader,src);gl.compileShader(shader);if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(shader));return shader}
      const p=gl.createProgram();gl.attachShader(p,compile(gl.VERTEX_SHADER,vertex));gl.attachShader(p,compile(gl.FRAGMENT_SHADER,fragment));gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw Error('Ocean shader link error');gl.useProgram(p);
      const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);const a=gl.getAttribLocation(p,'p');gl.enableVertexAttribArray(a);gl.vertexAttribPointer(a,2,gl.FLOAT,false,0,0);
      const uSize=gl.getUniformLocation(p,'resolution'),uRatio=gl.getUniformLocation(p,'pixelRatio'),video=$('#surf');
      const texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
      function resize(){if(!canvas.clientWidth)return;const ratio=Math.min(devicePixelRatio,1.5);canvas.width=Math.max(1,Math.round(canvas.clientWidth*ratio));canvas.height=Math.max(1,Math.round(canvas.clientHeight*ratio));gl.viewport(0,0,canvas.width,canvas.height);gl.uniform2f(uSize,canvas.width,canvas.height);gl.uniform1f(uRatio,ratio);drawSea?.(Math.max(drawTime,0))}
      drawSea=t=>{if(video.readyState<2)return;gl.uniform1f(gl.getUniformLocation(p,'aspect'),video.videoWidth/video.videoHeight);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGB,gl.RGB,gl.UNSIGNED_BYTE,video);gl.drawArrays(gl.TRIANGLES,0,6);evidence.seaFrames++;evidence.waveTime=video.currentTime;$('.ocean').classList.add('ready')};
      resizeSea=resize;resize();window.addEventListener('resize',resize);video.addEventListener('loadeddata',()=>drawSea?.(0));evidence.ocean='video-halftone';
      canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();drawSea=null;$('.ocean').classList.add('video-fallback');evidence.ocean='video-fallback'});
    }catch(e){$('.ocean').classList.add('video-fallback');evidence.ocean='video-fallback';evidence.oceanFallback=e.message}
  }
  setupSea();
  window.FRI_MOTION={render(t,force=false){
    const useTime=reduced.matches&&!force?0:t;
    if(force||useTime-drawTime>=1/30||drawTime<0){drawTime=useTime;if(activeRoute==='home'||force)drawSea?.(useTime);scramble(useTime);gallery(useTime);footerReveal()}
  }};
  showRoute(location.pathname.includes('/pricing')||location.hash==='#pricing'?'pricing':'home');window.FRI_MOTION.render(0,true);
})();
