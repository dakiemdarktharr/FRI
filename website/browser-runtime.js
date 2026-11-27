// Browser calendar: OCR stays on this device. No API key or calendar backend.
window.FRI_WEB_APP=true;
window.friBrowser={
 async service(action,input){
  if(action==='ai-status')return {ready:false};
  if(action!=='ocr')throw Error('Use the desktop app for connected websites and PDF/Word files. Here you can import images, ICS, CSV, JSON or text.');
  if(typeof input!=='string'||!/^data:image\/(png|jpeg|webp);base64,/.test(input)||input.length>12*1024*1024)throw Error('Choose a PNG, JPEG or WebP under 8 MB.');
  let worker,timer;
  try{
   if(!window.Tesseract)await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='/ocr/tesseract.min.js';script.onload=resolve;script.onerror=()=>{script.remove();reject(Error('The local reader could not load. Check your connection and retry.'))};document.head.append(script)});
   worker=await window.Tesseract.createWorker('vie',1,{workerPath:'/ocr/worker.min.js',corePath:'/ocr/',langPath:'/ocr/',cacheMethod:'none',workerBlobURL:false,errorHandler:()=>{}});
   await worker.setParameters({tessedit_pageseg_mode:window.Tesseract.PSM.SPARSE_TEXT});
   const blob=await (await fetch(input)).blob(),bitmap=await createImageBitmap(blob);
   if(bitmap.width*bitmap.height>40000000){bitmap.close();throw Error('Choose an image under 40 megapixels.');}
   const canvas=document.createElement('canvas'),scale=Math.min(1,2400/Math.max(bitmap.width,bitmap.height));canvas.width=Math.round(bitmap.width*scale);canvas.height=Math.round(bitmap.height*scale);canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);bitmap.close();
   const {data}=await Promise.race([worker.recognize(canvas),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Reading took too long. Try a clearer, smaller image.')),60000)})]);canvas.width=0;canvas.height=0;return {text:data.text};
  }finally{clearTimeout(timer);await worker?.terminate()}
 }
};
