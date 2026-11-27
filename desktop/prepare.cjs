const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.join(__dirname, '..');
// HTML parsing normalizes line endings before CSP hash validation.
const html = fs.readFileSync(path.join(root, 'FRI-liquid-glass.html'), 'utf8').replace(/\r\n?/g, '\n');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => `'sha256-${crypto.createHash('sha256').update(m[1]).digest('base64')}'`);
const csp = `default-src 'none'; script-src ${scripts.join(' ')}; style-src 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'; media-src blob:; worker-src blob:; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`;
fs.mkdirSync(path.join(__dirname, 'ui'), {recursive:true});
fs.copyFileSync(path.join(root,'apple/Packages/FRICore/Sources/FRICore/Resources/meeting-agent.js'),path.join(__dirname,'ui/meeting-agent.js'));
fs.writeFileSync(path.join(__dirname, 'ui/index.html'), html);
fs.writeFileSync(path.join(__dirname, 'ui/csp.json'), JSON.stringify(csp));
console.log('Prepared desktop UI with hashed scripts and an offline content policy.');

for(const [name] of require('../brand/typography.cjs').weights) fs.copyFileSync(path.join(root,'brand/fonts/be-vietnam-pro/BeVietnamPro-'+name+'.woff2'),path.join(__dirname,'ui/BeVietnamPro-'+name+'.woff2'));
fs.rmSync(path.join(__dirname,'ui/InterVariable.woff2'),{force:true});
fs.writeFileSync(path.join(__dirname,'ui/typography-embedded.css'),require('../brand/typography.cjs').typography());
fs.copyFileSync(path.join(root,'brand/fonts/be-vietnam-pro/OFL.txt'),path.join(__dirname,'ui/FONT-LICENSE.txt'));
for(const name of ['fri-mark.svg','first-plan.svg']) fs.copyFileSync(path.join(root,'brand',name),path.join(__dirname,'ui',name));
