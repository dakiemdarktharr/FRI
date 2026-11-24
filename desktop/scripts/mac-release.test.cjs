'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {notarizationOptions} = require('./build-mac.cjs');
test('public build rejects absent and partial notarization credentials', () => {
  for (const env of [{},{APPLE_ID:'test'},{APPLE_API_KEY:'/missing'},{APPLE_ID:'test',APPLE_KEYCHAIN_PROFILE:'fallback'}]) {
    assert.throws(() => notarizationOptions(env));
  }
});
test('keychain notarization does not require exposing an Apple password', () => {
  assert.deepEqual(notarizationOptions({APPLE_KEYCHAIN_PROFILE:'fri-release'}), {keychainProfile:'fri-release'});
});
test('publication rejects development, missing architecture and modified artifacts', () => {
  const fs = require('node:fs'), path = require('node:path'), os = require('node:os'), crypto = require('node:crypto');
  const {checkReceipt} = require('./check-mac-receipt.cjs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(),'fri-receipt-test-'));
  try {
    const version = require('../package.json').version;
    const artifacts = ['arm64','x64'].flatMap(arch => ['dmg','zip'].map(ext => {
      const name = `FRI-${version}-mac-${arch}.${ext}`;
      fs.writeFileSync(path.join(dir,name),'test fixture');
      return {name,sha256:crypto.createHash('sha256').update('test fixture').digest('hex')};
    }));
    const write = data => fs.writeFileSync(path.join(dir,'mac-verification.json'),JSON.stringify(data));
    write({distributionReady:false,artifacts}); assert.throws(() => checkReceipt(dir), /Development/);
    write({distributionReady:true,artifacts:artifacts.slice(0,2)}); assert.throws(() => checkReceipt(dir), /both architectures/);
    write({distributionReady:true,artifacts}); checkReceipt(dir);
    fs.appendFileSync(path.join(dir,artifacts[0].name),'tampered');
    assert.throws(() => checkReceipt(dir), /changed after verification/);
  } finally {fs.rmSync(dir,{recursive:true,force:true});}
});
