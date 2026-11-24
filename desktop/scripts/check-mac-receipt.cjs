'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
function checkReceipt(directory) {
  const receipt = JSON.parse(fs.readFileSync(path.join(directory,'mac-verification.json'),'utf8'));
  if (receipt.distributionReady !== true) throw new Error('Development artifacts cannot be published');
  const version = require('../package.json').version;
  const expected = ['arm64','x64'].flatMap(arch => ['dmg','zip'].map(ext => `FRI-${version}-mac-${arch}.${ext}`)).sort();
  if (JSON.stringify(receipt.artifacts.map(item => item.name).sort()) !== JSON.stringify(expected)) throw new Error('Release must contain both architectures and both formats');
  const actual = fs.readdirSync(directory).filter(name => /\.(dmg|zip)$/.test(name)).sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error('Unexpected or stale Mac artifacts');
  for (const item of receipt.artifacts) {
    const hash = crypto.createHash('sha256').update(fs.readFileSync(path.join(directory,item.name))).digest('hex');
    if (hash !== item.sha256) throw new Error(`Artifact changed after verification: ${item.name}`);
  }
}
module.exports = {checkReceipt};
if (require.main === module) {
  try {checkReceipt(process.argv[2]); console.log('PASS Mac release receipt and payload hashes');}
  catch (error) {console.error(error.message); process.exitCode = 1;}
}
