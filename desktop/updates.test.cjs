'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events');
const {createUpdates,newer}=require('./updates.cjs');
function fixture(options={}){
 const updater=new EventEmitter(),calls={check:0,download:0,install:0},published=[];
 updater.checkForUpdates=async()=>{calls.check++;updater.emit('update-available',{version:'0.7.0'})};
 updater.downloadUpdate=async()=>{calls.download++;updater.emit('download-progress',{percent:42.9});updater.emit('update-downloaded',{version:'0.7.0'})};
 updater.quitAndInstall=(silent,reopen)=>{calls.install++;assert.equal(silent,false);assert.equal(reopen,true)};
 const updates=createUpdates({updater,version:'0.6.0',platform:'win32',packaged:true,publish:s=>published.push(s),...options});
 return {updater,updates,calls,published};
}
test('detects updates without downloading; explicit download and restart preserve state transitions',async()=>{
 const {updater,updates,calls,published}=fixture();assert.equal(updater.autoDownload,false);assert.equal(updater.autoInstallOnAppQuit,false);assert.equal(updater.allowDowngrade,false);
 assert.equal((await updates.check()).phase,'available');assert.equal(calls.download,0);
 assert.equal((await updates.download()).phase,'ready');assert.ok(published.some(s=>s.phase==='downloading'&&s.percent===42));assert.equal(calls.install,0);
 assert.equal((await updates.install()).phase,'installing');assert.equal(calls.install,1);updates.stop();
});
test('duplicate check and download clicks perform one operation',async()=>{
 const {updater,updates,calls}=fixture();let finish;
 updater.checkForUpdates=()=>{calls.check++;return new Promise(r=>{finish=()=>{updater.emit('update-available',{version:'0.7.0'});r()}})};
 const a=updates.check(),b=updates.check();await Promise.resolve();assert.equal(calls.check,1);finish();await Promise.all([a,b]);
 updater.downloadUpdate=()=>{calls.download++;return new Promise(r=>{finish=()=>{updater.emit('update-downloaded',{version:'0.7.0'});r()}})};
 const c=updates.download(),d=updates.download();await Promise.resolve();assert.equal(calls.download,1);finish();await Promise.all([c,d]);assert.equal(updates.read().phase,'ready');updates.stop();
});
test('development and test builds cannot check, download or install',async()=>{
 for(const options of [{packaged:false},{testMode:true}]){const {updates,calls}=fixture(options);assert.equal((await updates.check()).phase,'unavailable');assert.equal(calls.check,0);await assert.rejects(updates.download());await assert.rejects(updates.install());updates.stop()}
});
test('unsigned macOS advertises the release download without invoking an installer',async()=>{
 let opened=0;const {updates,calls}=fixture({platform:'darwin',openReleases:async()=>opened++});assert.equal((await updates.check()).phase,'manual');await assert.rejects(updates.download());await assert.rejects(updates.install());await updates.call('open-releases');assert.equal(opened,1);assert.equal(calls.install,0);updates.stop();
});
test('download failures and mismatched artifacts never become installable',async()=>{
 for(const fail of ['error','mismatch']){const {updater,updates,calls}=fixture();await updates.check();updater.downloadUpdate=async()=>{if(fail==='error'){updater.emit('error',Error('private-path'));throw Error('secret')}updater.emit('update-downloaded',{version:'99.0.0'})};assert.equal((await updates.download()).phase,'error');assert.equal(JSON.stringify(updates.read()).includes('private-path'),false);await assert.rejects(updates.install());assert.equal(calls.install,0);updates.stop()}
});
test('declining restart or failing to save keeps the downloaded update ready',async()=>{
 for(const options of [{confirmInstall:async()=>false},{prepareInstall:async()=>{throw Error('disk-full')}}]){const {updates,calls}=fixture(options);await updates.check();await updates.download();assert.equal((await updates.install()).phase,'ready');assert.equal(calls.install,0);updates.stop()}
});
test('install waits for persisted calendar writes and duplicate clicks cannot launch twice',async()=>{
 let flush;const {updates,calls}=fixture({prepareInstall:()=>new Promise(r=>flush=r)});await updates.check();await updates.download();const first=updates.install(),second=updates.install();await new Promise(r=>setImmediate(r));assert.equal(calls.install,0);flush();await Promise.all([first,second]);assert.equal(calls.install,1);updates.stop();
});
test('unknown actions, malformed/downgrade versions and unsolicited downloads are rejected',async()=>{
 const {updater,updates}=fixture();await assert.rejects(updates.call('run-shell'));updater.emit('update-downloaded',{version:'0.7.0'});assert.equal(updates.read().phase,'idle');
 for(const version of ['0.5.9','0.6.0','0.7.0-beta','file:///evil']){updater.checkForUpdates=async()=>updater.emit('update-available',{version});assert.equal((await updates.check()).phase,'error')}
 assert.equal(newer('1.0.0','0.9.99'),true);updates.stop();
});
test('current and network error states are truthful and checks preserve a ready download',async()=>{
 const {updater,updates,calls}=fixture();updater.checkForUpdates=async()=>updater.emit('update-not-available');assert.equal((await updates.check()).phase,'current');updater.checkForUpdates=async()=>{throw Error('offline')};assert.equal((await updates.check()).phase,'error');
 updater.checkForUpdates=async()=>{calls.check++;updater.emit('update-available',{version:'0.7.0'})};await updates.check();await updates.download();await updates.check();assert.equal(updates.read().phase,'ready');assert.equal(calls.check,1);updates.stop();
});
test('shutdown stops actions and safely absorbs an in-flight updater error',async()=>{
 const {updater,updates,calls}=fixture();await updates.check();await updates.download();updates.stop();updater.emit('error',Error('connection closed during quit'));await assert.rejects(updates.install());assert.equal(calls.install,0);
});
