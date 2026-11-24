'use strict';
// Run from any directory: node apple/Tools/verify-backup-interop.cjs
// Uses the shipping desktop validator/restore handler and actual Swift sources.
// This is a format/persistence contract test, not an Electron file-dialog test.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const { validate } = require(path.join(root, 'desktop/store.cjs'));
const source = fs.readFileSync(path.join(root, 'preview/app.js'), 'utf8');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'fri-backup-interop-'));
const clone = value => JSON.parse(JSON.stringify(value));

function requiredMatch(pattern) {
  const match = source.match(pattern);
  assert.ok(match, 'Desktop source changed; update the harness extraction before trusting this check');
  return match[0];
}

const dateHelpers = ['dateKey', 'dateOf', 'shiftDate', 'minutes'].map(name =>
  requiredMatch(new RegExp(`^const ${name}=.*;$`, 'm'))).join('\n');
const desktopSeed = requiredMatch(/^const demo=\[[\s\S]*?^const seed=.*;$/m);
const desktopExport = requiredMatch(/^ if\(command==='export'\).*$/m);
const desktopRestore = requiredMatch(/^\$\('#backup-file'\)\.addEventListener\('change',async e=>\{[\s\S]*?^\}\);/m);

async function exportInDesktop(state) {
  let exported;
  const sandbox = {
    command: 'export', state, today: '2026-11-23', Blob,
    URL: { createObjectURL: blob => { exported = blob; return 'blob:fixture'; }, revokeObjectURL: () => {} },
    document: { createElement: () => ({ click() {} }) }, setTimeout: () => {}, toast: () => {}
  };
  vm.runInNewContext(`(() => {${desktopExport}\n})()`, sandbox);
  assert.ok(exported, 'Desktop export must produce a file');
  return JSON.parse(await exported.text());
}

async function restoreInDesktop(backup, expectedTasks) {
  // Execute the real handler. Stub only browser presentation and disk-save hooks.
  // The initial state has different settings so the existing tasks-only restore
  // behavior is explicit and cannot be mistaken for full-state interoperability.
  let handler, confirmed = false, saved = false, toast = '';
  const restoreButton = {};
  const original = { version: 1, tasks: [], settings: { retainedDesktopSetting: true }, finished: [] };
  const sandbox = {
    state: clone(original), today: '2026-11-23',
    $: selector => {
      if (selector === '#backup-file') return { addEventListener: (_, callback) => { handler = callback; } };
      if (selector === '#restore-backup') return restoreButton;
      throw Error(`Unexpected desktop dependency: ${selector}`);
    },
    openModal: () => { confirmed = true; }, closeModal: () => {}, openDay: () => {}, render: () => {},
    save: () => { validate(sandbox.state); saved = true; return true; },
    toast: message => { toast = message; }
  };
  vm.createContext(sandbox);
  vm.runInContext(`${dateHelpers}\n${desktopRestore}`, sandbox);
  const json = JSON.stringify(backup);
  await handler({ target: { files: [{ size: Buffer.byteLength(json), text: async () => json }], value: 'fixture.json' } });
  if (expectedTasks === null) {
    assert.equal(confirmed, false);
    assert.match(toast, /not a valid/);
    assert.deepEqual(clone(sandbox.state), original);
  } else {
    assert.equal(confirmed, true, toast);
    restoreButton.onclick();
    assert.equal(saved, true);
    assert.deepEqual(clone(sandbox.state.tasks), expectedTasks.map(task => ({
      ...task, done: !!task.done, kind: task.kind === 'deadline' ? 'deadline' : 'schedule'
    })));
    assert.deepEqual(clone(sandbox.state.settings), original.settings);
  }
}

async function main() {
  const core = path.join(root, 'apple/Packages/FRICore');
  const sources = path.join(temporary, 'Sources/BackupProbe');
  fs.mkdirSync(sources, { recursive: true });
  fs.copyFileSync(path.join(__dirname, 'BackupInterop.swift'), path.join(sources, 'BackupInterop.swift'));
  fs.writeFileSync(path.join(temporary, 'Package.swift'), `// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "BackupProbe", platforms: [.macOS(.v14)],
    dependencies: [.package(path: ${JSON.stringify(core)})],
    targets: [.executableTarget(name: "BackupProbe", dependencies: [.product(name: "FRICore", package: "FRICore")])])
`);
  const args = ['swift', 'build', '--package-path', temporary];
  const build = spawnSync('xcrun', args, { encoding: 'utf8' });
  assert.equal(build.status, 0, build.stdout + build.stderr);
  const bin = spawnSync('xcrun', [...args, '--show-bin-path'], { encoding: 'utf8' });
  assert.equal(bin.status, 0, bin.stderr);
  const executable = path.join(bin.stdout.trim(), 'BackupProbe');
  const state = vm.runInNewContext(`${dateHelpers}\nlet today='2026-11-23';\n${desktopSeed}\nseed()`);
  const fixture = { format: 'fri-backup', schema: 1, state: clone(state) };
  fixture.state.tasks.push({ id: 'desktop-deadline', title: 'Hạn nộp — 🗓️', date: '2026-11-24',
    time: '23:59', duration: 0, kind: 'deadline', category: 'Work', location: '', notes: 'First\nSecond, third', done: false });
  fixture.state.drafts = [{ ...fixture.state.tasks[0], id: 'unfinished-import', title: 'Chưa chọn giờ',
    date: '', time: '', duration: 0, kind: 'schedule', done: false, sourceKey: 'fixture:unfinished' }];
  fixture.state.importQueue = [{ id: 'qa-source', label: 'Timetable', rows: [{ title: 'Vật lý', date: '', kind: 'schedule', sourceKey: 'qa-row' }],
    links: [], warnings: [], status: 'attention', settings: { workStart: 540, workEnd: 1080 } }];
  fixture.state.sourceLibrary = [{ id: 'qa-source', label: 'Timetable', links: [], readAt: 1 }];
  fixture.state.settings.futureOption = { nested: [true, 3.5, 'giữ nguyên', null] };
  assert.deepEqual(await exportInDesktop(fixture.state), fixture);
  validate(fixture.state);
  await restoreInDesktop(fixture, fixture.state.tasks);
  const input = path.join(temporary, 'desktop.json');
  const output = path.join(temporary, 'native.json');
  fs.writeFileSync(input, JSON.stringify(fixture));
  const converted = spawnSync(executable, [input, output], { encoding: 'utf8' });
  assert.equal(converted.status, 0, converted.stderr);
  const native = JSON.parse(fs.readFileSync(output, 'utf8'));
  validate(native.state);
  assert.deepEqual(native.state.importQueue, fixture.state.importQueue);
  assert.deepEqual(native.state.sourceLibrary, fixture.state.sourceLibrary);
  assert.deepEqual(native.state.tasks.slice(0, -1), fixture.state.tasks);
  for (const key of ['settings', 'drafts', 'tabs', 'active', 'collections', 'widgets', 'finished']) {
    assert.deepEqual(native.state[key], fixture.state[key], `Swift lost ${key}`);
  }
  assert.equal(native.state.tasks.at(-1).title, 'Lịch từ Swift — ☕️');
  await restoreInDesktop(native, native.state.tasks);
  console.log('PASS desktop seed + deadline + unfinished draft → encrypted Swift store → reopen → native export → desktop restore');

  const mutations = [
    ['wrong schema', data => { data.schema = 2; }],
    ['duplicate IDs', data => { data.state.tasks.push(clone(data.state.tasks[0])); }],
    ['invalid date', data => { data.state.tasks[0].date = '2026-02-30'; }],
    ['crosses midnight', data => { data.state.tasks[0].time = '23:59'; }],
    ['zero-minute schedule', data => { data.state.tasks[0].duration = 0; }],
    ['nonzero deadline', data => { data.state.tasks.at(-1).duration = 1; }],
    ['title beyond UTF-16 limit', data => { data.state.tasks[0].title = '🗓'.repeat(81); }]
  ];
  for (const [name, mutate] of mutations) {
    const invalid = clone(fixture);
    mutate(invalid);
    await restoreInDesktop(invalid, null);
    fs.writeFileSync(input, JSON.stringify(invalid));
    const before = fs.readFileSync(output);
    const rejected = spawnSync(executable, [input, output], { encoding: 'utf8' });
    assert.equal(rejected.status, 1, `${name}: ${rejected.stderr}`);
    assert.deepEqual(fs.readFileSync(output), before, `${name}: output was overwritten`);
    console.log(`PASS both readers reject ${name}`);
  }
  console.log('LIMIT: desktop restore imports appointments only; native retains full compatible state. No GUI, signing or release claim.');
}

main().catch(error => { console.error(error); process.exitCode = 1; })
  .finally(() => fs.rmSync(temporary, { recursive: true, force: true }));
