const assert = require('node:assert/strict');
const { once } = require('node:events');
const fs = require('node:fs/promises');
const http = require('node:http');
const path = require('node:path');
const { after, before, test } = require('node:test');
const { pathToFileURL } = require('node:url');
const { AxeBuilder } = require('@axe-core/playwright');
const { chromium, devices, webkit } = require('playwright');

const htmlPath = path.join(__dirname, '../index.html');
const engine = process.env.FRI_BROWSER === 'webkit' ? webkit : chromium;
const { defaultBrowserType, ...iphone } = devices['iPhone 13'];
let browser;
let server;
let appUrl;

before(async () => {
  const html = await fs.readFile(htmlPath);
  server = http.createServer((req, res) => {
    if (req.url !== '/' && !req.url.startsWith('/?')) {
      res.writeHead(404).end();
      return;
    }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }).end(html);
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  appUrl = `http://127.0.0.1:${server.address().port}/`;
  browser = await engine.launch();
});

after(async () => {
  await browser?.close();
  server?.close();
});

async function open(t, options = {}, url = appUrl) {
  const context = await browser.newContext({ locale: 'en-GB', timezoneId: 'Asia/Ho_Chi_Minh', ...options });
  t.after(() => context.close());
  const page = await context.newPage();
  page.setDefaultTimeout(3500);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  t.after(() => assert.deepEqual(errors, [], 'No uncaught browser errors'));
  await page.goto(url);
  return { page, context };
}

const byButton = (scope, name) => scope.getByRole('button', { name, exact: typeof name === 'string' });
const bodyText = page => page.locator('body').innerText();
const navigate = (page, name) => page.getByRole('navigation').getByRole('button', { name, exact: typeof name === 'string' })
  .or(page.getByRole('navigation').getByRole('link', { name, exact: typeof name === 'string' })).first().click();
const monthTile = (page, date) => page.locator(`.month-tile[data-id="${date}"]`);
const yearTile = (page, month) => page.locator(`.year-tile[data-id="${month}"]`);
const activity = (page, itemId) => page.locator(`.activity-open[data-id="${itemId}"]`);
const activityPost = (page, itemId) => page.locator('article.activity-post').filter({ has: activity(page, itemId) });
const view = (page, name) => byButton(page.locator('#main'), name);

async function capture(page, name) {
  const directory = process.env.FRI_TEST_SCREENSHOTS;
  if (!directory) return;
  await fs.mkdir(directory, { recursive: true });
  await page.screenshot({ path: path.join(directory, `${name}.png`), fullPage: true });
}

async function appearance(page) {
  return page.evaluate(() => {
    const root = document.documentElement;
    const style = getComputedStyle(root);
    return {
      palette: root.dataset.theme, mode: root.dataset.mode,
      background: style.getPropertyValue('--bg').trim(), primary: style.getPropertyValue('--primary').trim(),
      accent: style.getPropertyValue('--accent').trim()
    };
  });
}

async function assertRoundedSquare(locator, label) {
  const size = await locator.boundingBox();
  assert.ok(size && Math.abs(size.width - size.height) <= 2, `${label} is square`);
  const radius = await locator.evaluate(element => Number.parseFloat(getComputedStyle(element).borderTopLeftRadius));
  assert.ok(radius > 0, `${label} has rounded corners`);
}

async function delayedPreview(page, target, delay) {
  await page.mouse.move(2, 2);
  await target.scrollIntoViewIfNeeded();
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const bounds = await target.boundingBox();
  assert.ok(bounds);
  const time = new Date('2026-11-23T08:00:00+07:00').getTime();
  await page.clock.install({ time });
  await page.clock.pauseAt(time + 1000);
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
  const preview = page.locator('#fri-hover');
  assert.equal(await preview.isVisible(), false);
  await page.clock.runFor(delay - 1);
  assert.equal(await preview.isVisible(), false, `preview stays hidden through ${delay - 1}ms`);
  await page.clock.runFor(1);
  assert.equal(await preview.isVisible(), true, `preview opens at ${delay}ms`);
  await page.clock.resume();
  return preview;
}

test('standalone HTML opens directly from disk', async t => {
  const { page } = await open(t, { viewport: { width: 1280, height: 960 } }, pathToFileURL(htmlPath).href);
  assert.match(await bodyText(page), /Robotics/i);
  assert.match(await bodyText(page), /07:15/);
  assert.equal(await byButton(page, 'Add sources').first().isVisible(), true);
  assert.equal(await page.locator('html').getAttribute('lang'), 'en');
  assert.equal(await view(page, 'Day').getAttribute('aria-pressed'), 'true');
  assert.equal(await view(page, 'Week').count(), 0);
  assert.equal(await view(page, 'List').count(), 0);
  await view(page, 'Month').click();
  await page.reload();
  assert.equal(await view(page, 'Day').getAttribute('aria-pressed'), 'true');
  await capture(page, 'desktop');
});

test('mobile can access the agenda and source action without page overflow', async t => {
  const { page } = await open(t, { ...iphone, viewport: { width: 360, height: 780 } });
  assert.match(await bodyText(page), /Robotics/i);
  const sourceAction = await byButton(page, 'Add sources').first().boundingBox();
  const { viewport, content } = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth, content: document.documentElement.scrollWidth
  }));
  assert.ok(content <= viewport + 1, `page is ${content}px wide in a ${viewport}px viewport`);
  assert.ok(sourceAction && sourceAction.x >= 0 && sourceAction.x + sourceAction.width <= viewport && sourceAction.height >= 44);
  const header = page.locator('#top');
  const headerBounds = await header.boundingBox();
  assert.ok(headerBounds);
  const topControls = await header.getByRole('button').all();
  assert.ok(topControls.length >= 2);
  for (const control of topControls) {
    const bounds = await control.boundingBox();
    assert.ok(bounds && bounds.y >= headerBounds.y && bounds.y + bounds.height <= headerBounds.y + headerBounds.height,
      'mobile actions fit vertically inside the header');
  }
  assert.match(await activityPost(page, 'school-trip').innerText(), /07:15/);
  await capture(page, 'mobile');
  await view(page, 'Year').tap();
  await yearTile(page, '2026-11').tap();
  assert.equal(await view(page, 'Month').getAttribute('aria-pressed'), 'true');
  await monthTile(page, '2026-11-24').tap();
  assert.equal(await view(page, 'Day').getAttribute('aria-pressed'), 'true');
  assert.match(await bodyText(page), /UX Research/);
  await activity(page, 'ux-research').tap();
  assert.equal(await page.getByRole('dialog').isVisible(), true);
});

test('keyboard selection retains the date across calendar views and restores focus on Escape', async t => {
  const { page } = await open(t);
  await view(page, 'Month').click();
  await monthTile(page, '2026-11-23').focus();
  await page.keyboard.press('ArrowRight');
  assert.equal(await monthTile(page, '2026-11-24').evaluate(element => document.activeElement === element), true);
  await page.keyboard.press('Enter');
  assert.equal(await view(page, 'Day').getAttribute('aria-pressed'), 'true');
  assert.match(await bodyText(page), /UX Research/);
  const classButton = activity(page, 'ux-research');
  await classButton.focus();
  await page.keyboard.press('Enter');
  const dialog = page.getByRole('dialog');
  await dialog.waitFor();
  await page.keyboard.press('Escape');
  await dialog.waitFor({ state: 'hidden' });
  assert.equal(await classButton.evaluate(element => document.activeElement === element), true);
  await view(page, 'Month').click();
  const selected = monthTile(page, '2026-11-24');
  assert.ok(['true', 'date'].includes(await selected.getAttribute('aria-pressed') || await selected.getAttribute('aria-current')));
  await view(page, 'Year').click();
  await yearTile(page, '2026-12').focus();
  await page.keyboard.press('Enter');
  assert.equal(await view(page, 'Month').getAttribute('aria-pressed'), 'true');
  await monthTile(page, '2026-12-15').focus();
  await page.keyboard.press('Enter');
  assert.equal(await view(page, 'Day').getAttribute('aria-pressed'), 'true');
  assert.match(await page.locator('#main').innerText(), /(?:15 December|December 15)/);
  await view(page, 'Jump to date').click();
  const jump = page.getByRole('dialog', { name: 'Choose date' });
  await jump.getByLabel('Date to open', { exact: true }).fill('2026-11-24');
  await byButton(jump, 'Go to date').click();
  assert.match(await page.locator('#main').innerText(), /UX Research/);
});

test('Month and Year tiles are rounded squares and the Month preview waits 500ms', async t => {
  const { page } = await open(t, { reducedMotion: 'reduce' });
  await view(page, 'Year').click();
  const november = yearTile(page, '2026-11');
  await assertRoundedSquare(november, 'year tile');
  await november.click();
  const monday = monthTile(page, '2026-11-23');
  await assertRoundedSquare(monday, 'month tile');
  const preview = await delayedPreview(page, monday, 500);
  assert.match(await preview.innerText(), /Robotics/);
  await capture(page, 'month-preview');
  await page.mouse.move(2, 2);
  assert.equal(await preview.isVisible(), false);
  await monday.click();
  assert.equal(await view(page, 'Day').getAttribute('aria-pressed'), 'true');
  assert.equal(await preview.isVisible(), false);
});

test('activity preview waits 300ms and the full details open on click', async t => {
  const { page } = await open(t, { reducedMotion: 'reduce' });
  const robotics = activity(page, 'robotics');
  const preview = await delayedPreview(page, robotics, 300);
  assert.match(await preview.innerText(), /Robotics/);
  await robotics.click();
  const detail = page.getByRole('dialog', { name: /Robotics/ });
  assert.equal(await detail.isVisible(), true);
  assert.equal(await preview.isVisible(), false);
});

test('day completion is gated on all activities and resets when an activity reopens', async t => {
  const { page } = await open(t);
  const complete = page.locator('.day-complete');
  const ring = page.locator('.day-ring[role="progressbar"], .day-ring [role="progressbar"]').first();
  assert.equal(await complete.getAttribute('aria-pressed'), 'false');
  assert.equal(await complete.isDisabled(), true);
  const unfinished = page.locator('.activity-tick[aria-checked="false"]');
  const checked = page.locator('.activity-tick[aria-checked="true"]');
  const missing = await unfinished.count();
  assert.ok(missing > 0);
  assert.equal(await ring.getAttribute('aria-valuemax'), String(await page.locator('.activity-tick').count()));
  for (let remaining = missing - 1; remaining >= 0; remaining--) {
    await unfinished.first().click();
    assert.equal(await unfinished.count(), remaining);
    assert.equal(await complete.isDisabled(), remaining > 0);
  }
  assert.equal(await ring.getAttribute('aria-valuenow'), await ring.getAttribute('aria-valuemax'));
  await complete.click();
  assert.equal(await complete.getAttribute('aria-pressed'), 'true');
  await view(page, 'Next day').click();
  assert.equal(await complete.getAttribute('aria-pressed'), 'false');
  await view(page, 'Previous day').click();
  await page.reload();
  assert.equal(await complete.getAttribute('aria-pressed'), 'true');
  await checked.first().click();
  assert.equal(await complete.getAttribute('aria-pressed'), 'false');
  assert.equal(await complete.isDisabled(), true);
  assert.equal(await unfinished.count(), 1);
});

test('appointment batch asks for one missing field at a time and saves the whole batch together', async t => {
  const { page } = await open(t);
  const first = 'Design team meeting';
  const second = 'Document review';
  const agenda = page.locator('#main');
  await byButton(page.locator('#top'), 'Add appointment').click();
  const entry = page.getByRole('dialog', { name: 'Add appointment' });
  await byButton(entry, 'New appointment').click();
  assert.match(await entry.getByRole('alert').innerText(), /Enter an appointment name/i);
  await entry.getByLabel('Appointment name', { exact: true }).fill(first);
  await entry.getByLabel('Date', { exact: true }).fill('2026-11-23');
  await entry.getByLabel('Start time', { exact: true }).fill('15:30');
  await entry.getByLabel('End time', { exact: true }).fill('16:00');
  await entry.getByLabel('Location (optional)', { exact: true }).fill('Gold meeting room');
  await entry.getByLabel('Notes (optional)', { exact: true }).fill('Bring the latest printout.');
  await byButton(entry, 'New appointment').click();
  assert.equal(await entry.getByLabel('Appointment name', { exact: true }).inputValue(), '');
  await entry.getByLabel('Appointment name', { exact: true }).fill(second);
  await entry.getByLabel('Date', { exact: true }).fill('');
  await byButton(entry, 'Done').click();

  const review = page.getByRole('dialog', { name: 'Complete appointment details' });
  const next = byButton(review, 'Continue');
  const progress = review.getByRole('progressbar', { name: 'Appointment details progress' });
  const assertNotPublished = async () => {
    const calendar = await agenda.innerText();
    assert.ok(!calendar.includes(first) && !calendar.includes(second));
  };
  await assertNotPublished();
  assert.match(await review.innerText(), /Question 1\s*\/\s*3/i);
  assert.equal(await progress.getAttribute('aria-valuemax'), '3');
  await capture(page, 'appointment-clarification');
  await review.getByLabel('Date', { exact: true }).fill('2026-11-23');
  await next.click();
  assert.match(await review.innerText(), /Question 2\s*\/\s*3/i);
  await review.getByLabel('Start time', { exact: true }).fill('16:15');
  await next.click();
  assert.match(await review.innerText(), /Question 3\s*\/\s*3/i);
  assert.equal(await progress.getAttribute('aria-valuenow'), '2');
  const end = review.getByLabel('End time', { exact: true });
  await end.fill('16:14');
  await next.click();
  assert.match(await review.getByRole('alert').innerText(), /after the start time/i);
  assert.equal(await end.isVisible(), true);
  await assertNotPublished();
  await end.fill('16:50');
  await next.click();
  await review.waitFor({ state: 'hidden' });

  assert.match(await agenda.innerText(), new RegExp(first));
  assert.match(await agenda.innerText(), new RegExp(second));
  await page.reload();
  await byButton(agenda, first).click();
  const saved = page.getByRole('dialog', { name: first });
  assert.match(await saved.innerText(), /Gold meeting room/);
  assert.match(await saved.innerText(), /Bring the latest printout/);
});

test('mobile appointment capture and clarification can be closed and resumed after reload', async t => {
  const { page } = await open(t, { ...iphone, viewport: { width: 360, height: 780 } });
  const title = 'Mobile test appointment';
  const top = page.locator('#top');
  await byButton(top, 'Add appointment').tap();
  const entry = page.getByRole('dialog', { name: 'Add appointment' });
  await entry.getByLabel('Appointment name', { exact: true }).fill(title);
  await entry.getByLabel('Date', { exact: true }).fill('2026-11-23');
  await capture(page, 'appointment-mobile');
  await byButton(entry, 'Close').tap();
  await entry.waitFor({ state: 'hidden' });
  assert.ok(!(await page.locator('#main').innerText()).includes(title));
  await page.reload();

  const reopen = byButton(top, /^(?:Continue appointments|Add appointment)$/i);
  await reopen.tap();
  assert.equal(await entry.getByLabel('Appointment name', { exact: true }).inputValue(), title);
  assert.equal(await entry.getByLabel('Date', { exact: true }).inputValue(), '2026-11-23');
  await byButton(entry, 'Done').tap();
  const review = page.getByRole('dialog', { name: 'Complete appointment details' });
  const next = byButton(review, 'Continue');
  await review.getByLabel('Start time', { exact: true }).fill('18:10');
  await next.tap();
  await page.reload();

  await reopen.tap();
  assert.match(await review.innerText(), /Question 2\s*\/\s*2/i);
  assert.ok(!(await page.locator('#main').innerText()).includes(title));
  await review.getByLabel('End time', { exact: true }).fill('18:40');
  await next.tap();
  await review.waitFor({ state: 'hidden' });
  assert.match(await page.locator('#main').innerText(), new RegExp(title));
});

test('a failed calendar write can be retried and a stale draft cannot duplicate it', async t => {
  const { page } = await open(t);
  const title = 'Appointment recovered after failure';
  const top = page.locator('#top');
  const reopen = byButton(top, /^(?:Continue appointments|Add appointment)$/i);
  await reopen.click();
  const entry = page.getByRole('dialog', { name: 'Add appointment' });
  await entry.getByLabel('Appointment name', { exact: true }).fill(title);
  await entry.getByLabel('Date', { exact: true }).fill('2026-11-23');
  await entry.getByLabel('Start time', { exact: true }).fill('18:10');
  await entry.getByLabel('End time', { exact: true }).fill('18:40');
  await page.evaluate(() => {
    const write = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'fri-web-v1') throw new DOMException('Test calendar write failure', 'QuotaExceededError');
      return write.call(this, key, value);
    };
  });
  await byButton(entry, 'Done').click();
  const retry = page.getByRole('dialog', { name: 'Save appointments' });
  assert.match(await retry.innerText(), /couldn[’']t save to your calendar/i);
  assert.ok(!(await page.locator('#main').innerText()).includes(title));
  const draft = await page.evaluate(() => localStorage.getItem('fri-appointment-draft-v1'));
  assert.ok(draft);

  await page.reload();
  await reopen.click();
  await byButton(retry, 'Save to calendar').click();
  const saved = byButton(page.locator('article.activity-post'), title);
  assert.equal(await saved.count(), 1);
  await page.evaluate(draft => localStorage.setItem('fri-appointment-draft-v1', draft), draft);
  await page.reload();
  await reopen.click();
  assert.equal(await entry.getByLabel('Appointment name', { exact: true }).inputValue(), '');
  await byButton(entry, 'Close').click();
  assert.equal(await saved.count(), 1);
});

test('desktop initial view has accessible names and landmark structure', async t => {
  const { page } = await open(t, { viewport: { width: 1280, height: 960 } });
  const result = await new AxeBuilder({ page }).withRules([
    'aria-allowed-attr', 'aria-required-attr', 'aria-roles', 'button-name', 'label', 'landmark-one-main', 'link-name'
  ]).analyze();
  assert.deepEqual(result.violations.map(({ id, nodes }) => ({ id, nodes: nodes.map(node => node.target) })), []);
});

test('default colors are solid beige and rosewood with no gradients in the interface', async t => {
  const { page } = await open(t);
  const colors = await page.evaluate(() => {
    const body = getComputedStyle(document.body);
    const heading = getComputedStyle(document.querySelector('.calendar-heading h1'));
    const appointment = getComputedStyle(document.querySelector('#top [data-action="appointment"]'));
    return {
      background: body.backgroundColor, image: body.backgroundImage,
      accent: appointment.backgroundColor, text: heading.color
    };
  });
  assert.equal(colors.background, 'rgb(241, 227, 212)');
  assert.equal(colors.image, 'none');
  assert.equal(colors.accent, 'rgb(149, 82, 81)');
  assert.equal(colors.text, 'rgb(45, 33, 30)');
  assert.doesNotMatch((await page.locator('style').allTextContents()).join('\n'), /\b(?:linear|radial|conic)-gradient\s*\(/i);

  const surfaces = 'body, #top, .activity-post, .day-ring, .month-tile, .year-tile, .fri-widget, .widget-face, .widget-stack-row';
  async function assertSolidSurfaces() {
    const gradients = await page.locator(surfaces).evaluateAll(elements => elements.flatMap(element =>
      [null, '::before', '::after'].flatMap(pseudo => {
        const { backgroundImage } = getComputedStyle(element, pseudo);
        return /gradient\(/i.test(backgroundImage) ? [{ element: element.className || element.tagName, pseudo, backgroundImage }] : [];
      })
    ));
    assert.deepEqual(gradients, []);
    assert.equal(await page.locator('linearGradient, radialGradient').count(), 0);
  }

  await assertSolidSurfaces();
  await view(page, 'Month').click();
  await assertSolidSurfaces();
  await view(page, 'Year').click();
  await assertSolidSurfaces();
  await byButton(page, 'Widgets').first().click();
  await view(page, 'Show upcoming activities').click();
  await assertSolidSurfaces();
});

test('palette and light/dark changes take effect and persist after a reload', async t => {
  const { page } = await open(t, { colorScheme: 'light' });
  const initial = await appearance(page);
  await byButton(page, 'Settings').first().click();
  assert.equal(await byButton(page, 'Beige · Rosewood').getAttribute('aria-pressed'), 'true');
  await byButton(page, 'Ink · Cyan').click();
  const alternatePalette = await appearance(page);
  assert.notDeepEqual(alternatePalette, initial);
  assert.equal(alternatePalette.background.toUpperCase(), '#EEF0FA');
  await byButton(page, 'Dark').first().click();
  const dark = await appearance(page);
  assert.notDeepEqual(dark, alternatePalette);
  assert.equal(dark.background.toUpperCase(), '#151835');
  await capture(page, 'settings-dark');
  await page.reload();
  assert.deepEqual(await appearance(page), dark);
});

test('sample sources keep the successful drafts and preserve the unresolved item across reload', async t => {
  const { page } = await open(t);
  await byButton(page, 'Add sources').first().click();
  await byButton(page, 'Use sample data').first().click();
  await page.getByText(/tomorrow at 7/i).first().waitFor();
  assert.match(await bodyText(page), /Review the prototype with the team/);
  await capture(page, 'sample-sources');
  await navigate(page, 'Sources');
  const retry = byButton(page, 'Try again').first();
  await retry.click();
  await retry.waitFor();
  await page.reload();
  await navigate(page, /Review/);
  assert.match(await bodyText(page), /tomorrow at 7/i);
  assert.equal(await page.getByText('Review the prototype with the team', { exact: true }).count(), 1);
});

test('two images can be staged and manually reviewed while offline', async t => {
  const { page, context } = await open(t);
  await context.setOffline(true);
  await byButton(page, 'Add sources').first().click();
  const pngs = [
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGPk9/7PgA0wYRUdtBIAEP0BaRM1kVAAAAAASUVORK5CYII=',
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGNMuSPHgA0wYRUdtBIAFhEBbntIvIUAAAAASUVORK5CYII='
  ];
  await page.locator('#source-files').setInputFiles(pngs.map((encoded, index) => ({
    name: `lich-${index + 1}.png`, mimeType: 'image/png', buffer: Buffer.from(encoded, 'base64')
  })));
  assert.equal(await byButton(page.getByRole('dialog'), 'Remove file').count(), 2);
  await byButton(page, 'Read sources').first().click();
  const drafts = page.getByRole('navigation', { name: 'Drafts' });
  await byButton(drafts, /lich-1\.png/).waitFor();
  await byButton(drafts, /lich-2\.png/).click();
  const evidence = page.getByRole('img', { name: 'Evidence image for lich-2.png' });
  await evidence.waitFor();
  assert.equal(await evidence.evaluate(image => image.naturalWidth), 8);
  await page.getByLabel('Name', { exact: true }).fill('Appointment transcribed offline');
  await page.getByLabel('Date', { exact: true }).fill('2026-11-27');
  await page.getByLabel('Start time', { exact: true }).fill('11:00');
  await page.getByLabel('End time', { exact: true }).fill('12:00');
  await byButton(page, 'Confirm').first().click();
  assert.match(await bodyText(page), /Confirmed/i);
  await byButton(drafts, /lich-1\.png/).waitFor();
  await context.setOffline(false);
  await page.reload();
  await navigate(page, 'Calendar');
  await view(page, 'Month').click();
  await monthTile(page, '2026-11-27').click();
  assert.match(await bodyText(page), /Appointment transcribed offline/);
});

test('changed ICS data has evidence and preserves a meeting location changed by the user', async t => {
  const { page } = await open(t);
  const url = 'https://calendar.example.test/course.ics';
  const title = 'Updated workshop';
  let revision = 1;
  await page.route(url, route => route.fulfill({
    contentType: 'text/calendar',
    headers: { 'Access-Control-Allow-Origin': '*' },
    body: [
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'BEGIN:VEVENT', 'UID:course-123', `SUMMARY:${title}`, `SEQUENCE:${revision}`,
      `DTSTART;TZID=Asia/Ho_Chi_Minh:${revision === 1 ? '20261125T100000' : '20261125T103000'}`,
      `DTEND;TZID=Asia/Ho_Chi_Minh:${revision === 1 ? '20261125T110000' : '20261125T113000'}`,
      `LOCATION:${revision === 1 ? 'Room A1' : 'Room B2'}`, 'END:VEVENT', 'END:VCALENDAR'
    ].join('\r\n')
  }));
  await byButton(page, 'Add sources').first().click();
  await page.getByLabel(/Calendar links/).fill(url);
  await byButton(page, 'Read sources').first().click();
  await page.getByText(title, { exact: true }).first().waitFor();
  const location = page.getByLabel('Location', { exact: true });
  await location.fill('My chosen location');
  await byButton(page, 'Confirm').first().click();

  revision = 2;
  await navigate(page, 'Sources');
  await byButton(page, 'Check again').first().click();
  await navigate(page, /Review/);
  await page.getByText(/Source updated/i).first().waitFor();
  assert.match(await bodyText(page), /10:30/);
  assert.match(await bodyText(page), /My chosen location/);
  assert.equal(await location.inputValue(), 'My chosen location');
  await capture(page, 'source-revision');
  await byButton(page, 'Confirm changes').first().click();
  await page.reload();
  await navigate(page, /Review/);
  assert.doesNotMatch(await bodyText(page), /Source updated/i);
});

test('planning preview applies, undoes and exports a schedulable task after reload', async t => {
  const { page } = await open(t);
  await byButton(page, 'Plan tasks').click();
  const preview = page.getByRole('dialog', { name: 'Preview plan' });
  assert.match(await preview.innerText(), /Write the prototype report/);
  assert.match(await preview.innerText(), /10:30.*11:30/);
  await byButton(page, 'Apply plan').first().click();
  const block = activityPost(page, 'prototype-review');
  assert.match(await block.innerText(), /10:30/);
  await byButton(page, 'Undo').click();
  assert.doesNotMatch((await block.allTextContents()).join(' '), /10:30/);
  await byButton(page, 'Plan tasks').click();
  await byButton(page, 'Apply plan').first().click();
  await capture(page, 'planned');
  await page.reload();
  assert.match(await block.innerText(), /10:30/);
  await byButton(page, 'Settings').first().click();
  const downloaded = page.waitForEvent('download');
  await byButton(page, 'Export Fri calendar').click();
  const exportFile = await downloaded;
  assert.equal(exportFile.suggestedFilename(), 'fri-plan.ics');
  const contents = await fs.readFile(await exportFile.path(), 'utf8');
  assert.match(contents, /SUMMARY:Write the prototype report/);
  assert.match(contents, /DTSTART:20261123T033000Z/);
  assert.equal((contents.match(/BEGIN:VEVENT/g) || []).length, 1);
});

test('rescheduling offers a different time and a locked session cannot be rescheduled', async t => {
  const { page } = await open(t);
  const slideBlock = activityPost(page, 'slides');
  assert.match(await slideBlock.innerText(), /14:00/);
  await activity(page, 'slides').click();
  const dialog = page.getByRole('dialog');
  await byButton(dialog, 'Find another time').click();
  assert.doesNotMatch(await dialog.innerText(), /14:00–15:00/);
  await byButton(dialog, 'Apply plan').click();
  assert.doesNotMatch(await slideBlock.innerText(), /14:00/);
  await activity(page, 'slides').click();
  await byButton(dialog, 'Lock session').click();
  assert.equal(await byButton(dialog, 'Unlock session').isVisible(), true);
  assert.equal(await byButton(dialog, 'Find another time').count(), 0);
});

test('a newer edit in another tab invalidates a previously opened plan preview', async t => {
  const { page, context } = await open(t);
  await byButton(page, 'Plan tasks').click();
  const otherTab = await context.newPage();
  otherTab.setDefaultTimeout(3500);
  await otherTab.goto(appUrl);
  await byButton(otherTab.locator('#top'), 'Add appointment').click();
  const entryForm = otherTab.getByRole('dialog', { name: 'Add appointment' });
  await entryForm.getByLabel('Appointment name', { exact: true }).fill('New appointment from another tab');
  await entryForm.getByLabel('Date', { exact: true }).fill('2026-11-23');
  await entryForm.getByLabel('Start time', { exact: true }).fill('10:30');
  await entryForm.getByLabel('End time', { exact: true }).fill('11:00');
  await byButton(entryForm, 'Done').click();
  await entryForm.waitFor({ state: 'hidden' });
  const preview = page.getByRole('dialog');
  await byButton(preview, 'Apply plan').click();
  assert.match(await preview.innerText(), /The calendar changed/);
  await byButton(preview, 'Preview again').click();
  assert.match(await preview.innerText(), /11:00.*12:00/);
});

test('widget stack opens, previews privacy and tint, and deep links to the correct trip', async t => {
  const { page } = await open(t);
  const total = await page.locator('.activity-tick').count();
  await byButton(page, 'Widgets').first().click();
  const face = page.locator('.widget-face');
  const stack = page.locator('.widget-deck .widget-stack-row');
  const travel = stack.filter({ hasText: /Head to campus|07:15/i }).first();
  await assertRoundedSquare(face, 'widget face');
  assert.match(await face.innerText(), new RegExp(String.raw`/\s*${total}\s+complete`));
  assert.equal(await face.getAttribute('aria-expanded'), 'false');
  assert.equal(await travel.isVisible(), false);
  await view(page, 'Show upcoming activities').press('Space');
  assert.equal(await face.getAttribute('aria-expanded'), 'true');
  assert.match(await travel.innerText(), /07:15/);
  await view(page, 'Hide upcoming activities').click();
  assert.equal(await face.getAttribute('aria-expanded'), 'false');
  const lock = page.locator('.widget-lock');
  assert.doesNotMatch(await lock.innerText(), /Campus/);
  await page.getByLabel('Hide details on the lock screen', { exact: true }).uncheck();
  assert.match(await lock.innerText(), /Campus/);
  await page.getByLabel('System tint', { exact: true }).check();
  assert.match(await page.locator('.fri-widget').getAttribute('class'), /tinted/);
  await view(page, 'Show upcoming activities').click();
  await capture(page, 'widgets');
  await travel.click();
  const details = page.getByRole('dialog');
  assert.match(await details.innerText(), /Head to campus/);
  assert.match(await details.innerText(), /07:15/);
  assert.equal(new URL(page.url()).hash, '#calendar/item/school-trip');
  await page.reload();
  assert.match(await details.innerText(), /Head to campus/);
});
