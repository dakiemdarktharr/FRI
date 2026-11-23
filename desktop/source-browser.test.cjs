const {test}=require('node:test'),assert=require('node:assert/strict');
const {relatedLinks,partitionFor}=require('./source-browser.cjs');
test('source crawling follows only observed same-origin read-only views',()=>{
 const root='https://example.com',links=['/calendar/view.php?view=month','/mod/assign/view.php?id=8','/course/view.php?id=7','/mod/assign/view.php?id=8&action=submit','/calendar/view.php?sesskey=private','/login/logout.php','https://other.example/calendar/view.php','/mod/assign/view.php?redirect=https://private.invalid'].map(url=>({title:'Page',url:new URL(url,root).href}));
 assert.equal(relatedLinks({url:root,links}).length,3);
 assert.notEqual(partitionFor(root),partitionFor('https://other.example'));assert.match(partitionFor(root),/^persist:fri-source-[a-f0-9]{24}$/);
});
