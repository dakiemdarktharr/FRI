'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {run, verifyArtifact} = require('./verify-mac.cjs');

function notarizationOptions(env) {
  if (env.APPLE_ID || env.APPLE_APP_SPECIFIC_PASSWORD) {
    if (!env.APPLE_ID || !env.APPLE_APP_SPECIFIC_PASSWORD || !env.APPLE_TEAM_ID) throw new Error('Set all three Apple ID notarization variables');
    return {appleId:env.APPLE_ID, appleIdPassword:env.APPLE_APP_SPECIFIC_PASSWORD, teamId:env.APPLE_TEAM_ID};
  }
  if (env.APPLE_API_KEY || env.APPLE_API_KEY_ID || env.APPLE_API_ISSUER) {
    if (!env.APPLE_API_KEY || !env.APPLE_API_KEY_ID || !env.APPLE_API_ISSUER) throw new Error('Set all three Apple API notarization variables');
    return {appleApiKey:env.APPLE_API_KEY, appleApiKeyId:env.APPLE_API_KEY_ID, appleApiIssuer:env.APPLE_API_ISSUER};
  }
  if (env.APPLE_KEYCHAIN_PROFILE) return {keychainProfile:env.APPLE_KEYCHAIN_PROFILE, ...(env.APPLE_KEYCHAIN ? {keychain:env.APPLE_KEYCHAIN} : {})};
  throw new Error('Notarization credentials are missing. Configure APPLE_KEYCHAIN_PROFILE locally or Apple notarization secrets in CI. No public artifact was built.');
}
async function main() {
  if (process.platform !== 'darwin') throw new Error('Mac artifacts must be built and verified on macOS');
  const args = process.argv.slice(2), development = args.includes('--development');
  const requested = args.filter(arg => arg !== '--development');
  if (requested.some(arg => !['arm64','x64'].includes(arg))) throw new Error('Supported arguments: --development arm64 x64');
  const architectures = requested.length ? requested : ['arm64','x64'];
  const projectDir = path.resolve(__dirname, '..');
  const output = path.resolve(projectDir, '../dist', development ? 'mac-development' : 'mac-release');
  // A receipt only describes this run, never an old successful run.
  fs.rmSync(path.join(output, 'mac-verification.json'), {force:true});
  const credentials = development ? null : notarizationOptions(process.env);
  if (!development && process.env.CSC_IDENTITY_AUTO_DISCOVERY === 'false') throw new Error('Signing is disabled; refusing a public Mac build');
  if (!development && !process.env.CSC_LINK && !run('security',['find-identity','-v','-p','codesigning']).includes('Developer ID Application:')) {
    throw new Error('Install a Developer ID Application certificate with its private key, or configure CSC_LINK in CI');
  }
  require('../prepare.cjs');
  const {build, Platform, Arch} = require('electron-builder');
  const files = await build({projectDir, publish:'never',
    targets:Platform.MAC.createTarget(['dmg','zip'], ...architectures.map(arch => Arch[arch])),
    config:{forceCodeSigning:true, directories:{output},
      ...(development ? {artifactName:'FRI-${version}-mac-${arch}-development.${ext}'} : {}),
      mac:{type:'distribution', hardenedRuntime:!development, notarize:!development,
        ...(development ? {identity:'-'} : {})},
      // DMGs are stapled below. Update manifests must only hash the unchanged ZIP.
      dmg:{sign:!development, writeUpdateInfo:false}}
  });
  const artifacts = [...new Set(files)].filter(file => /\.(dmg|zip)$/.test(file));
  if (artifacts.length !== architectures.length * 2) throw new Error('Missing requested Mac artifacts');
  for (const file of artifacts) {
    if (!development && file.endsWith('.dmg')) {
      await require('@electron/notarize').notarize({appPath:file, ...credentials});
    }
    verifyArtifact(file, development);
  }
  const hashes = artifacts.map(file => ({name:path.basename(file), sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')}));
  fs.writeFileSync(path.join(output,'SHA256SUMS-mac.txt'), hashes.map(item => `${item.sha256}  ${item.name}`).join('\n')+'\n');
  fs.writeFileSync(path.join(output,'mac-verification.json'), JSON.stringify({distributionReady:!development, artifacts:hashes}, null, 2)+'\n');
  console.log(development ? 'Development artifacts only. Do not publish to website downloads.' : 'Mac distribution signatures, notarization and Gatekeeper checks passed.');
}
module.exports = {notarizationOptions};
if (require.main === module) main().catch(error => {console.error(error.message); process.exitCode = 1;});
