'use strict';
const path = require('node:path');
const {createWorker, OEM, PSM} = require('tesseract.js');

async function createMeetingOCR() {
  const realPath = p => p.replace(/([/\\])app\.asar([/\\])/, '$1app.asar.unpacked$2');
  const langPath = realPath(path.join(path.dirname(require.resolve('@tesseract.js-data/vie/package.json')), '4.0.0_best_int'));
  const workerPath = realPath(require.resolve('tesseract.js/src/worker-script/node/index.js'));
  const worker = await createWorker('vie', OEM.LSTM_ONLY, {langPath, workerPath, cacheMethod:'none', errorHandler:()=>{}});
  await worker.setParameters({tessedit_pageseg_mode: PSM.SPARSE_TEXT});
  return {
    stop: () => worker.terminate(),
    async lines(bytes, cropWidth) {
      const {data} = await worker.recognize(bytes, {}, {blocks:true, text:false});
      const lines = [];
      for (const block of data.blocks || []) for (const paragraph of block.paragraphs) for (const line of paragraph.lines) {
        const text=line.text.trim();
        if(!text || text.length>480 || /^[\d:./\s]+$/.test(text))continue;
        const left=0.25+0.74*line.bbox.x0/cropWidth;
        const right=0.25+0.74*line.bbox.x1/cropWidth;
        const side=left>=0.58 && right>0.78 ? 'own' : left<0.52 && right<0.80 ? 'other' : 'unknown';
        lines.push({y:line.bbox.y0, side, text});
      }
      return lines.sort((a,b)=>a.y-b.y);
    }
  };
}
module.exports={createMeetingOCR};
