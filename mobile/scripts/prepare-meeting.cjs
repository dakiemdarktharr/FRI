'use strict';
/* global __dirname */
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const source = path.join(root, 'apple/Packages/FRICore/Sources/FRICore/Resources/meeting-agent.js');
const target = path.join(root, 'mobile/src/generated/meeting-agent.js');
fs.mkdirSync(path.dirname(target), {recursive:true});
fs.copyFileSync(source, target);
const asset = path.join(root, 'mobile/modules/fri-android/android/src/main/assets/meeting');
fs.mkdirSync(asset, {recursive:true});
fs.copyFileSync(path.join(root,'brand/fonts/be-vietnam-pro/OFL.txt'),path.join(asset,'../FONT-LICENSE.txt'));
const compressed=fs.readFileSync(require.resolve('@tesseract.js-data/vie/4.0.0_best_int/vie.traineddata.gz', {paths:[path.join(root,'mobile'),path.join(root,'desktop')]}));
fs.writeFileSync(path.join(asset,'vie.traineddata'),require('node:zlib').gunzipSync(compressed));
fs.rmSync(path.join(asset,'vie.traineddata.gz'),{force:true});
console.log('Prepared shared meeting rules and bundled offline Vietnamese OCR.');

const fontPath=path.join(root,'mobile/modules/fri-android/android/src/main/res/font');
fs.mkdirSync(fontPath,{recursive:true});
for(const [source,target] of [['Regular','regular'],['SemiBold','semibold'],['Bold','bold']])fs.copyFileSync(path.join(root,'brand/fonts/be-vietnam-pro/BeVietnamPro-'+source+'.ttf'),path.join(fontPath,'be_vietnam_pro_'+target+'.ttf'));
for(const weight of ['regular','semibold','bold'])fs.rmSync(path.join(fontPath,'inter_'+weight+'.ttf'),{force:true});
// Incremental Expo prebuild keeps obsolete font resources from older releases.
for(const name of ['inter_regular.ttf','inter_semi_bold.ttf','inter_bold.ttf','xml_inter.xml'])fs.rmSync(path.join(root,'mobile/android/app/src/main/res/font',name),{force:true});
