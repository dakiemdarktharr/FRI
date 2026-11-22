const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../index.html'), 'utf8');
const scripts = Array.from(source.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi));
const domainStart = /\b(?:const|let|var) FriDomain\s*=/;
const domainSource = scripts.find(([, content]) => domainStart.test(content))?.[1];
assert.ok(domainSource, 'The HTML embeds FriDomain');

const sandbox = vm.createContext({ URL, URLSearchParams, structuredClone });
vm.runInContext(domainSource, sandbox, { filename: 'index.html (FriDomain)' });
const domain = vm.runInContext('FriDomain', sandbox);

const date = '2026-11-23';
const item = (id, kind, start, end, extra = {}) => ({
  id, title: id, kind, date, start, end, location: '', ...extra
});
const calendar = (...events) => ['BEGIN:VCALENDAR', 'VERSION:2.0', ...events.flat(), 'END:VCALENDAR'].join('\r\n');
const event = (...lines) => ['BEGIN:VEVENT', ...lines, 'END:VEVENT'];

test('calendar helpers preserve local dates across month, leap year and week boundaries', () => {
  assert.equal(domain.DEMO_DATE, date);
  assert.equal(domain.DEMO_ZONE, 'Asia/Ho_Chi_Minh');
  assert.equal(domain.addDays('2026-12-31', 1), '2027-01-01');
  assert.equal(domain.addDays('2028-03-01', -1), '2028-02-29');
  assert.equal(domain.startOfWeek('2026-11-29'), date);
  assert.equal(domain.formatTime(7 * 60 + 5), '07:05');
  assert.equal(domain.parseTime('07:05'), 425);
});

test('appointment clarification keeps row order and asks only unresolved fields', () => {
  const rows = [
    { id: 'a', title: '', date: '', start: '', end: '10:00' },
    { id: 'b', title: 'Có đủ dữ kiện', date, start: '07:30', end: '08:00' },
    { id: 'c', title: 'Giờ kết thúc không hợp lệ', date, start: '13:00', end: '12:30' }
  ];
  const questions = () => Array.from(domain.appointmentQuestions(rows), ({ rowId, field }) => [rowId, field]);
  assert.deepEqual(questions(), [['a', 'title'], ['a', 'date'], ['a', 'start'], ['c', 'end']]);
  rows[0] = { ...rows[0], title: 'Đã đặt tên', date };
  assert.deepEqual(questions(), [['a', 'start'], ['c', 'end']]);
  assert.equal(domain.appointmentQuestions(rows).at(-1).reason, 'order');
});

test('appointments crossing midnight require explicit next-day confirmation', () => {
  const row = { id: 'night', title: ' Hẹn tối ', date: '2026-12-31', start: '23:45', end: '00:30' };
  assert.equal(domain.appointmentItem(row), null);
  assert.equal(domain.appointmentItem({ ...row, end: row.start }), null);
  const overnight = domain.appointmentItem({ ...row, overnight: true });
  assert.equal(overnight.title, 'Hẹn tối');
  assert.equal(overnight.start, 1425);
  assert.equal(overnight.end, 30);
  assert.equal(overnight.endDate, '2027-01-01');
  assert.equal(domain.isDayItem(overnight, '2027-01-01'), true);
});

test('source text preserves ambiguous date and time with its original evidence', () => {
  for (const evidence of ['Họp nhóm mai 7h', 'Team meeting tomorrow at 7']) {
    const [draft] = domain.parseSourceText(evidence);
    assert.equal(draft.date, null);
    assert.equal(draft.start, null);
    assert.ok(draft.uncertain.length >= 2);
    assert.equal(draft.evidence, evidence);
  }
});

test('ICS keeps all-day dates distinct from instants and preserves evidence', () => {
  const [allDay, timed] = domain.parseIcs(calendar(
    event('UID:all-day', 'SUMMARY:Ngày hội', 'DTSTART;VALUE=DATE:20261124'),
    event('UID:timed', 'SUMMARY:Robotics', 'DTSTART:20261123T010000Z', 'DTEND:20261123T033000Z')
  ));
  assert.equal(allDay.date, '2026-11-24');
  assert.equal(allDay.endDate, '2026-11-25');
  assert.equal(allDay.start, null);
  assert.equal(allDay.temporal, 'date');
  assert.equal(timed.date, date);
  assert.equal(timed.start, 480);
  assert.equal(timed.end, 630);
  assert.equal(timed.instant, '2026-11-23T01:00:00.000Z');
  assert.match(timed.evidence, /DTSTART:20261123T010000Z/);
});

test('ICS treats ambiguous and nonexistent DST wall times as pending clarification', () => {
  const [fall, spring] = domain.parseIcs(calendar(
    event('UID:fall', 'SUMMARY:Fall back', 'DTSTART;TZID=America/New_York:20261101T013000'),
    event('UID:spring', 'SUMMARY:Spring forward', 'DTSTART;TZID=America/New_York:20260308T023000')
  ));
  for (const draft of [fall, spring]) {
    assert.equal(draft.temporal, 'floating');
    assert.equal(draft.instant, null);
    assert.match(draft.uncertain.join(' '), /clocks change/i);
  }
});

test('repeated ICS UIDs keep the newest sequence in the same response', () => {
  const [newest, ...more] = domain.parseIcs(calendar(
    event('UID:move-me', 'SUMMARY:Phiên đã dời', 'SEQUENCE:3', 'DTSTART:20261123T030000Z', 'DTEND:20261123T040000Z'),
    event('UID:move-me', 'SUMMARY:Phiên cũ', 'SEQUENCE:2', 'DTSTART:20261123T010000Z', 'DTEND:20261123T020000Z')
  ));
  assert.equal(newest.sourceKey, 'move-me');
  assert.equal(newest.sourceVersion, 3);
  assert.equal(newest.start, 600);
  assert.equal(more.length, 0);
});

test('adjacent fixed events do not overlap', () => {
  const first = item('first', 'fixed', 8 * 60, 9 * 60);
  const adjacent = item('adjacent', 'fixed', 9 * 60, 10 * 60);
  const overlap = item('overlap', 'fixed', 8 * 60 + 59, 10 * 60);
  assert.equal(domain.previewPlacement(adjacent, [first]).ok, true);
  assert.equal(domain.previewPlacement(overlap, [first]).ok, false);
  const result = domain.plan([first, overlap], date);
  assert.ok(result.conflicts.some(entry => entry.itemIds.includes('first') && entry.itemIds.includes('overlap')));
});

test('campus context permits compatible work and requires containment for a nested task', () => {
  const campus = item('campus', 'context', 8 * 60, 12 * 60, { location: 'Campus' });
  const classBlock = item('class', 'fixed', 9 * 60, 10 * 60, { location: 'Campus' });
  const work = item('report', 'task', 10 * 60, 11 * 60, { location: 'Campus' });
  const nested = item('lab', 'child', 9 * 60 + 15, 9 * 60 + 45, { location: 'Campus', parentId: classBlock.id });
  assert.equal(domain.previewPlacement(work, [campus, classBlock]).ok, true);
  assert.equal(domain.previewPlacement({ ...work, start: 9 * 60 + 30 }, [campus, classBlock]).ok, false);
  assert.equal(domain.previewPlacement(nested, [campus, classBlock]).ok, true);
  assert.equal(domain.previewPlacement({ ...nested, end: 10 * 60 + 1 }, [campus, classBlock]).ok, false);
  const outside = item('outside', 'task', null, null, { location: 'Campus', effort: 180 });
  const result = domain.plan([outside, campus, classBlock], date);
  assert.equal(result.placements.length, 0);
  assert.equal(result.shortages[0].capacity, 180);
  assert.equal(result.shortages[0].code, 'no-contiguous-time');
});

test('travel reserves time and identifies a five-minute connection shortfall', () => {
  const trip = item('commute', 'trip', null, null, {
    arriveBy: 9 * 60, duration: 30, buffer: 8, origin: 'Home', destination: 'Campus'
  });
  const block = domain.travelBlock(trip);
  assert.deepEqual(Array.from([block.start, block.end]), [502, 540]);
  const scheduled = item('campus-work', 'task', 8 * 60 + 30, 9 * 60, { location: 'Campus' });
  assert.equal(domain.previewPlacement(scheduled, [trip]).ok, false);

  const first = item('first', 'fixed', 13 * 60, 13 * 60 + 50, { location: 'Campus' });
  const second = item('second', 'fixed', 14 * 60 + 30, 15 * 60, { location: 'Studio' });
  const connection = item('transfer', 'trip', null, null, {
    origin: 'Campus', destination: 'Studio', arriveBy: second.start, duration: 45, buffer: 0
  });
  const result = domain.plan([first, second, connection], date);
  assert.ok(result.conflicts.some(entry => entry.minutes === 5));
});

test('planner proves a 90-minute shortfall and preserves locked blocks and rest time', () => {
  const writing = item('writing', 'task', null, null, { effort: 240, deadline: 660 });
  const locked = item('locked', 'task', 480, 495, { effort: 15, locked: true });
  const result = domain.plan([writing, locked], date, {
    revision: 5, availability: [{ start: 480, end: 900 }], breaks: [{ start: 600, end: 615 }], reschedule: true
  });
  assert.equal(result.placements.length, 0);
  const [shortage] = result.shortages;
  assert.equal(shortage.code, 'capacity');
  assert.equal(shortage.capacity, 150);
  assert.equal(shortage.minutes, 90);
  assert.equal(locked.start, 480);
});

test('planning preview needs the current revision and validation prevents conflicting placements', () => {
  const writing = item('writing', 'task', null, null, { effort: 60 });
  const block = item('class', 'fixed', 480, 540);
  const state = { items: [writing, block], revision: 4 };
  const proposal = domain.plan(state.items, date, { revision: state.revision });
  assert.equal(proposal.placements[0].start, 540);
  const stale = domain.commitPlan({ ...state, revision: 5 }, proposal);
  assert.equal(stale.ok, false);
  assert.equal(stale.code, 'stale');
  const collision = domain.commitPlan(state, {
    ...proposal, placements: [{ ...proposal.placements[0], start: 480, end: 540 }]
  });
  assert.equal(collision.ok, false);
  assert.equal(collision.code, 'invalid');
  const lunch = domain.commitPlan(state, {
    ...proposal, placements: [{ ...proposal.placements[0], start: 720, end: 780 }]
  });
  assert.equal(lunch.ok, false);
  assert.equal(lunch.code, 'invalid');
  const committed = domain.commitPlan(state, proposal);
  assert.equal(committed.ok, true);
  assert.equal(committed.revision, 5);
  assert.equal(committed.items[0].start, 540);
  assert.equal(state.items[0].start, null);
});

test('widget preview and travel reminder use the same revision with a stable identity', () => {
  const { items, revision } = domain.demoState();
  const prior = domain.snapshot(items, date, revision);
  assert.equal(prior.completed, 2);
  assert.equal(prior.total, 5);
  assert.equal(prior.trip.leaveAt, 435);
  const updated = domain.snapshot(items.map(item => item.id === 'school-trip' ? { ...item, buffer: 8 } : item), date, revision + 1);
  assert.equal(updated.trip.leaveAt, 432);
  assert.equal(updated.reminders.length, 1);
  assert.equal(updated.reminders[0].id, prior.reminders[0].id);
  assert.equal(updated.reminders[0].revision, updated.revision);
  assert.equal(updated.reminders[0].minute, updated.trip.leaveAt);
  assert.equal(updated.reminders[0].enabled, false);
});

test('source changes expose changed fields without modifying the original evidence values', () => {
  const original = { title: 'Robotics', start: 480, end: 630, location: 'B2' };
  const incoming = { ...original, start: 495, end: 645 };
  const diff = domain.candidateDiff(original, incoming);
  assert.deepEqual(Array.from(diff, row => [row.field, row.before, row.after]), [
    ['start', 480, 495], ['end', 630, 645]
  ]);
  assert.equal(original.start, 480);
});
