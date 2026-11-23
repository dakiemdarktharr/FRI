'use strict';
const https=require('node:https'),dns=require('node:dns/promises'),net=require('node:net');
function publicAddress(ip){
 if(net.isIP(ip)===4){const [a,b,c]=ip.split('.').map(Number);return !(a===0||a===10||a===127||a===169&&b===254||a===172&&b>=16&&b<=31||a===192&&b===168||a===100&&b>=64&&b<=127||a===198&&(b===18||b===19)||a===192&&b===0||a===198&&b===51&&c===100||a===203&&b===0&&c===113||a>=224)}
 return net.isIP(ip)===6&&/^[23][0-9a-f]{3}:/i.test(ip)&&!/^2001:(0{1,4}:|0?db8:)/i.test(ip)&&!/^2002:/i.test(ip);
}
async function validateSourceUrl(input){
 if(typeof input!=='string'||input.length>2048)throw Error('Use a public HTTPS calendar link');const url=new URL(input);if(url.protocol!=='https:'||url.username||url.password||url.port&&url.port!=='443'||url.hostname==='localhost')throw Error('Use a public HTTPS calendar link');
 let dnsTimer;const addresses=await Promise.race([dns.lookup(url.hostname,{all:true}),new Promise((_,reject)=>{dnsTimer=setTimeout(()=>reject(Error('Source address lookup timed out')),5000)})]).finally(()=>clearTimeout(dnsTimer));if(!addresses.length||addresses.some(a=>!publicAddress(a.address)))throw Error('Private and local network addresses are not supported');
 return {url,addresses};
}
async function readPublicDetails(input,depth=0){
 const {url,addresses}=await validateSourceUrl(input);
 return new Promise((resolve,reject)=>{let settled=false;const end=(error,value)=>{if(settled)return;settled=true;clearTimeout(timer);error?reject(error):resolve(value)};
  const request=https.get(url,{agent:false,lookup:(_host,options,cb)=>options.all?cb(null,addresses):cb(null,addresses[0].address,addresses[0].family),headers:{accept:'text/calendar, application/ld+json, text/html;q=0.8, text/plain;q=0.7','user-agent':'FRI/0.3 calendar import'}},response=>{
   if([301,302,303,307,308].includes(response.statusCode)&&response.headers.location){response.resume();if(depth>=5){end(Error('This link redirected too many times.'));return}let next;try{next=new URL(response.headers.location,url).href}catch{end(Error('Invalid source redirect'));return}readPublicDetails(next,depth+1).then(v=>end(null,v),e=>end(e));return}
   if([401,403].includes(response.statusCode)){response.resume();end(null,{state:'sign-in',url:url.href,text:'',status:response.statusCode});return}
   if(response.statusCode<200||response.statusCode>=300){response.resume();end(Error('This source is unavailable (HTTP '+response.statusCode+').'));return}
   let length=0,chunks=[];response.on('data',chunk=>{length+=chunk.length;if(length>2*1024*1024){request.destroy();end(Error('This page is too large. Open a smaller calendar section.'))}else chunks.push(chunk)});response.on('end',()=>{const text=Buffer.concat(chunks).toString('utf8'),login=/<input\b[^>]*type\s*=\s*["']?password/i.test(text)||/\/(login|signin|auth)(\/|\.|\?|$)/i.test(url.pathname);end(null,{state:login?'sign-in':'ready',url:url.href,text:login?'':text,contentType:response.headers['content-type']||''})});response.on('error',()=>end(Error('Source download failed')))
  });const timer=setTimeout(()=>{request.destroy();end(Error('Source download timed out'))},10000);request.on('error',()=>end(Error('Source download failed')));
 });
}
async function readPublicSource(input){const result=await readPublicDetails(input);if(result.state!=='ready')throw Error('Sign in to read this source.');return result.text}
module.exports={publicAddress,readPublicSource,readPublicDetails,validateSourceUrl};
