'use strict';
const {Worker,isMainThread,parentPort,workerData}=require('node:worker_threads');
function readDocument(input){
 if(!input||typeof input.name!=='string'||! /\.(pdf|docx)$/i.test(input.name)||typeof input.data!=='string'||input.data.length>12*1024*1024||!/^data:[^,]{0,150};base64,[A-Za-z0-9+/=]+$/.test(input.data))return Promise.reject(Error('Choose a PDF or DOCX under 8 MB.'));
 const bytes=Buffer.from(input.data.split(',')[1],'base64');if(bytes.length>8*1024*1024)return Promise.reject(Error('Choose a document under 8 MB.'));
 return new Promise((resolve,reject)=>{const worker=new Worker(__filename,{workerData:{bytes,kind:/\.pdf$/i.test(input.name)?'pdf':'docx'},resourceLimits:{maxOldGenerationSizeMb:256}}),timer=setTimeout(()=>{worker.terminate();reject(Error('Document took too long to read. Export a smaller file.'))},30000);worker.once('message',r=>{clearTimeout(timer);worker.terminate();r.error?reject(Error(r.error)):resolve(r)});worker.once('error',()=>{clearTimeout(timer);reject(Error('This document could not be read. Export it as text or ICS.'))});worker.once('exit',code=>{clearTimeout(timer);if(code)reject(Error('Document reading stopped. Try a smaller file.'))})});
}
async function extract({bytes,kind}){
 const buffer=Buffer.from(bytes),warnings=[];let text='';
 if(kind==='pdf'){
  const {getDocument}=await import('pdfjs-dist/legacy/build/pdf.mjs');const assets=require('node:path').dirname(require.resolve('pdfjs-dist/package.json')).replaceAll('\\','/')+'/';const task=getDocument({data:new Uint8Array(buffer),useSystemFonts:false,isEvalSupported:false,useWorkerFetch:false,standardFontDataUrl:assets+'standard_fonts/',cMapUrl:assets+'cmaps/',cMapPacked:true});let document;
  try{document=await task.promise;const limit=Math.min(document.numPages,100);if(document.numPages>100)warnings.push('Only the first 100 PDF pages were read.');for(let i=1;i<=limit;i++){const page=await document.getPage(i),content=await page.getTextContent();text+=content.items.map(item=>item.str+(item.hasEOL?'\n':' ')).join('')+'\n';page.cleanup();if(text.length>60000){warnings.push('Document text was limited to 60,000 characters.');break}}}finally{await task.destroy()}
 }else{
  // Reject zip bombs before the DOCX library inflates XML. No linked resources are fetched.
  let total=0,count=0;for(let i=0;i<buffer.length-46;i++){if(buffer.readUInt32LE(i)!==0x02014b50)continue;const size=buffer.readUInt32LE(i+24);total+=size;count++;if(size>8*1024*1024||total>32*1024*1024||count>2000)throw Error('This DOCX expands beyond the document limit. Export it as text.');i+=45+buffer.readUInt16LE(i+28)+buffer.readUInt16LE(i+30)+buffer.readUInt16LE(i+32)}
  if(!count)throw Error('Not a valid DOCX document.');const result=await require('mammoth').extractRawText({buffer},{externalFileAccess:false});text=result.value;
 }
 if(!text.trim())throw Error('No text layer found. Export the scanned pages as images for visual extraction.');if(text.length>60000&&!warnings.length)warnings.push('Document text was limited to 60,000 characters.');return {text:text.slice(0,60000),warnings};
}
if(!isMainThread)extract(workerData).then(r=>parentPort.postMessage(r)).catch(error=>parentPort.postMessage({error:error.name==='PasswordException'?'This PDF is password protected. Export an unlocked copy first.':error.message}));
module.exports={readDocument};
