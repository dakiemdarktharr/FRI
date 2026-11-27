/* global __dirname */
'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const ts=require('typescript');
const requireFromLib=require('node:module').createRequire(path.resolve(__dirname,'../src/lib/meeting.ts'));
const code=ts.transpileModule(fs.readFileSync(path.join(__dirname,'../src/lib/meeting.ts'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,esModuleInterop:true,target:ts.ScriptTarget.ES2020}}).outputText;
const result={exports:{}};vm.runInNewContext(code,{exports:result.exports,module:result,require:requireFromLib,Date,Map,Math});const {proposeMeetings,stageMeeting,getMeeting,clearMeeting}=result.exports;
test('shared rules stay identical to the latest canonical source',()=>{
 assert.deepEqual(fs.readFileSync(path.join(__dirname,'../src/generated/meeting-agent.js')),fs.readFileSync(path.join(__dirname,'../../apple/Packages/FRICore/Sources/FRICore/Resources/meeting-agent.js')));
});
test('explicit sharing proposes invitations and preserves unknown date/time',()=>{
 const now=new Date(2026,10,25,10).getTime();
 const a=proposeMeetings('ê xíu 9h trạm k',now)[0];assert.equal(a.time,null);assert.equal(a.date,null);assert.equal(a.timeHint,'9h');assert.equal(a.location,'trạm');
 const plans=proposeMeetings('Thứ sáu 19:00 họp nhé?\nOk, mình đi',now);assert.equal(plans.length,1);assert.equal(plans[0].date,'2026-11-27');
 assert.equal(proposeMeetings('Hủy họp mai 19h\nMật khẩu của tôi là 1234\n9h',now).length,0);
});
test('draft replacement and cancellation never write a calendar',()=>{
 const a=stageMeeting({title:'A',date:null,time:null});assert.equal(getMeeting(a).title,'A');
 const b=stageMeeting({title:'B',date:null,time:null});assert.equal(getMeeting(a),undefined);clearMeeting(b);assert.equal(getMeeting(b),undefined);
});

test('concurrent mounted screens consume a shared invitation only once',async()=>{
 let calls=0;const read=async()=>{calls++;return {text:'Thứ sáu 19:00 họp nhé?'}};
 const a=result.exports.readSharedText('one',read),b=result.exports.readSharedText('one',read);
 assert.equal(a,b);assert.equal((await b).text,'Thứ sáu 19:00 họp nhé?');assert.equal(calls,1);
 await result.exports.readSharedText('two',read);assert.equal(calls,2);
});

test('new relative-time rules retain uncertainty after sharing',()=>{
 const now=new Date(2026,10,27,10).getTime();const plans=proposeMeetings('ê xíu trạm k',now);
 assert.equal(plans.length,1);assert.equal(plans[0].relativeTime,'Lát nữa');assert.equal(plans[0].date,null);assert.equal(plans[0].time,null);
 assert.equal(proposeMeetings('xíu trạm có mở cửa k',now).length,0);
});
