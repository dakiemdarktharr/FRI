import React, {useEffect} from 'react';
import {useThree} from '@react-three/fiber';
import {createRoot} from 'react-dom/client';
import {ShaderGradientCanvas, ShaderGradient} from '@shadergradient/react';
let root,lastTarget,lastKey;
function RenderBudget({paused}){const set=useThree(s=>s.setFrameloop),invalidate=useThree(s=>s.invalidate);useEffect(()=>{set(paused?'demand':'always');invalidate()},[paused,set,invalidate]);return null}
class SafeGradient extends React.Component {
  state={failed:false};
  static getDerivedStateFromError(){return {failed:true};}
  componentDidCatch(){document.documentElement.dataset.gradient='fallback';}
  render(){return this.state.failed?null:this.props.children;}
}
window.renderSidebarGradient = (enabled, paused=false) => {
  const target=document.getElementById('shader'),key=enabled+':'+paused;
  if(target===lastTarget&&key===lastKey)return;
  lastTarget=target;lastKey=key;
  if(root){root.unmount(); root=null;}
  if(!enabled||!target) return;
  const test=document.createElement('canvas');
  if(!test.getContext('webgl2')) {document.documentElement.dataset.gradient='fallback';return;}
  const gl=test.getContext('webgl2');gl.getExtension('WEBGL_lose_context')?.loseContext();
  root=createRoot(target);
  root.render(<SafeGradient><ShaderGradientCanvas style={{position:'absolute',inset:0}} pixelDensity={1} fov={45} lazyLoad={false} powerPreference="low-power" pointerEvents="none">
    <RenderBudget paused={paused}/><ShaderGradient control="props" type="plane" animate={paused?'off':'on'} uTime={6} uSpeed={0.08} uStrength={2.2} uDensity={1.15} uFrequency={3.2} color1="#eeeeee" color2="#171717" color3="#eeeeee" lightType="3d" brightness={1.05} grain="off" cDistance={3.8} cPolarAngle={90} cAzimuthAngle={180} positionX={-0.6} rotationZ={35} reflection={0} />
  </ShaderGradientCanvas></SafeGradient>);
};
window.syncGradient?.();
