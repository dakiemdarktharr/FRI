'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

function run(command, args) {
  const result = spawnSync(command, args, {encoding:'utf8'});
  const output = (result.stdout || '') + (result.stderr || '');
  if (result.error || result.status !== 0) throw new Error(`${command} failed: ${output || result.error?.message || `exit ${result.status}`}`);
  return output;
}
function verifyApp(app, development = false) {
  run('codesign', ['--verify', '--deep', '--strict', '--verbose=2', app]);
  const signature = run('codesign', ['--display', '--verbose=4', app]);
  if (!signature.includes('Identifier=com.fri.calendar\n')) throw new Error('Unexpected app signing identifier');
  if (development) return;
  if (!signature.includes('Authority=Developer ID Application:') ||
      !/TeamIdentifier=[A-Z0-9]{10}\b/.test(signature) || !signature.includes('runtime')) {
    throw new Error('Public Mac downloads require Developer ID signing and hardened runtime');
  }
  run('xcrun', ['stapler', 'validate', app]);
  run('spctl', ['--assess', '--type', 'execute', '--verbose=2', app]);
}
function verifyArtifact(file, development = false) {
  file = path.resolve(file);
  if (file.endsWith('.app')) return verifyApp(file, development);
  if (!/\.(dmg|zip)$/.test(file)) throw new Error('Expected a .app, .dmg or .zip');
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'fri-verify-'));
  let mounted = false;
  try {
    if (file.endsWith('.dmg')) {
      run('hdiutil', ['verify', file]);
      if (!development) {
        run('codesign', ['--verify', '--strict', file]);
        run('xcrun', ['stapler', 'validate', file]);
        run('spctl', ['--assess', '--type', 'open', '--context', 'context:primary-signature', file]);
      }
      run('hdiutil', ['attach', file, '-readonly', '-nobrowse', '-mountpoint', temporary]);
      mounted = true;
    } else {
      run('ditto', ['-x', '-k', file, temporary]);
    }
    verifyApp(path.join(temporary, 'FRI.app'), development);
  } finally {
    if (mounted) run('hdiutil', ['detach', temporary]);
    fs.rmSync(temporary, {recursive:true, force:true});
  }
  console.log(`PASS ${development ? 'development integrity only' : 'distribution trust'}: ${path.basename(file)}`);
}
module.exports = {run, verifyApp, verifyArtifact};
if (require.main === module) {
  const args = process.argv.slice(2), development = args.includes('--development');
  const files = args.filter(arg => arg !== '--development');
  if (!files.length) { console.error('Usage: node scripts/verify-mac.cjs [--development] file.app|file.dmg|file.zip'); process.exit(1); }
  try { for (const file of files) verifyArtifact(file, development); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
