'use strict';
const fs=require('node:fs/promises'),path=require('node:path'),{execFile}=require('node:child_process'),{promisify}=require('node:util'),{randomUUID}=require('node:crypto');
async function recognize(data,directory){
 if(process.platform!=='win32')throw Error('On-device image recognition is available on Windows. Read the image and enter the details below.');
 if(typeof data!=='string'||data.length>6*1024*1024||!/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(data))throw Error('Choose a PNG, JPEG or WebP under 4 MB');
 const bytes=Buffer.from(data.split(',')[1],'base64');if(bytes.length>4*1024*1024)throw Error('Image too large');const file=path.join(directory,'fri-ocr-'+randomUUID()+'.png');
 try{await fs.writeFile(file,bytes,{mode:0o600});const script=path.join(__dirname,'ocr.ps1').replace('app.asar','app.asar.unpacked');const {stdout}=await promisify(execFile)('powershell.exe',['-NoProfile','-NonInteractive','-File',script,'-ImagePath',file],{windowsHide:true,timeout:20000,maxBuffer:256*1024,encoding:'utf8'});const result=JSON.parse(stdout.replace(/^\uFEFF/,''));if(typeof result.text!=='string')throw Error();return {text:result.text.slice(0,20000),language:result.language}}
 catch{throw Error('This image could not be read on-device. You can still enter its details from the preview.')}
 finally{await fs.unlink(file).catch(()=>{})}
}
module.exports={recognize};
