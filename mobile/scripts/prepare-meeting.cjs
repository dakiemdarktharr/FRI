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
const compressed=fs.readFileSync(require.resolve('@tesseract.js-data/vie/4.0.0_best_int/vie.traineddata.gz', {paths:[path.join(root,'mobile'),path.join(root,'desktop')]}));
fs.writeFileSync(path.join(asset,'vie.traineddata'),require('node:zlib').gunzipSync(compressed));
fs.rmSync(path.join(asset,'vie.traineddata.gz'),{force:true});
console.log('Prepared shared meeting rules and bundled offline Vietnamese OCR.');

const fontPath=path.join(root,'mobile/modules/fri-android/android/src/main/res/font');
fs.mkdirSync(fontPath,{recursive:true});
for(const [source,target] of [['Regular','regular'],['SemiBold','semibold'],['Bold','bold']])fs.copyFileSync(path.join(root,'brand/fonts/Inter-'+source+'.ttf'),path.join(fontPath,'inter_'+target+'.ttf'));
