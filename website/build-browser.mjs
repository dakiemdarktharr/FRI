import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const here=path.dirname(fileURLToPath(import.meta.url)),require=createRequire(import.meta.url);
export async function buildBrowser(){
 const runtime=await readFile(path.join(here,'browser-runtime.js'),'utf8');
 let app=await readFile(path.join(here,'../FRI-liquid-glass.html'),'utf8');
 app=app.replace('<head>','<head><script>'+runtime+'</script>').replace('<title>FRI · Liquid Glass</title>','<title>Fri · Your calendar</title>');
 await mkdir(path.join(here,'public/app'),{recursive:true});await writeFile(path.join(here,'public/app/index.html'),app);
 const out=path.join(here,'public/ocr');await mkdir(out,{recursive:true});
 const tess=path.dirname(require.resolve('tesseract.js/package.json')),core=path.dirname(require.resolve('tesseract.js-core/package.json')),data=path.dirname(require.resolve('@tesseract.js-data/vie/package.json'));
 for(const name of ['tesseract.min.js','worker.min.js','tesseract.min.js.LICENSE.txt','worker.min.js.LICENSE.txt'])await copyFile(path.join(tess,'dist',name),path.join(out,name));
 for(const prefix of ['tesseract-core-lstm','tesseract-core-simd-lstm','tesseract-core-relaxedsimd-lstm'])for(const ext of ['.wasm.js','.wasm'])await copyFile(path.join(core,prefix+ext),path.join(out,prefix+ext));
 await copyFile(path.join(data,'4.0.0_best_int/vie.traineddata.gz'),path.join(out,'vie.traineddata.gz'));
 await copyFile(path.join(core,'LICENSE'),path.join(out,'TESSERACT-CORE-LICENSE.txt'));
 await copyFile(path.join(tess,'LICENSE.md'),path.join(out,'TESSERACT-JS-LICENSE.txt'));
 await copyFile(path.join(here,'../brand/fonts/be-vietnam-pro/OFL.txt'),path.join(here,'public/assets/FONT-LICENSE.txt'));
 await writeFile(path.join(out,'MODEL-NOTICE.txt'),'Vietnamese OCR model: @tesseract.js-data/vie 1.0.0. Package license: MIT. Upstream: https://github.com/naptha/tessdata . Tesseract recognition core: Apache-2.0; see TESSERACT-CORE-LICENSE.txt.');
 console.log('Built /app with on-device Vietnamese image recognition.');
}
