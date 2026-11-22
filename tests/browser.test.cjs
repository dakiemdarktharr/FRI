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
  const context = await browser.newContext({ locale: 'vi-VN', timezoneId: 'Asia/Ho_Chi_Minh', ...options });
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

test('standalone HTML opens directly from disk', async t => {
  const { page } = await open(t, { viewport: { width: 1280, height: 960 } }, pathToFileURL(htmlPath).href);
  assert.match(await bodyText(page), /Robotics/i);
  assert.match(await bodyText(page), /07:15/);
  assert.equal(await byButton(page, 'Thêm nguồn').first().isVisible(), true);
  assert.equal(await page.locator('.mobile-agenda').isVisible(), false);
  await capture(page, 'desktop');
});

test('mobile can access the agenda and source action without page overflow', async t => {
  const { page } = await open(t, { ...iphone, viewport: { width: 360, height: 780 } });
  assert.match(await bodyText(page), /Robotics/i);
  const sourceAction = await byButton(page, 'Thêm nguồn').first().boundingBox();
  const { viewport, content } = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth, content: document.documentElement.scrollWidth
  }));
  assert.ok(content <= viewport + 1, `page is ${content}px wide in a ${viewport}px viewport`);
  assert.ok(sourceAction && sourceAction.x >= 0 && sourceAction.x + sourceAction.width <= viewport && sourceAction.height >= 44);
  const header = page.locator('#top');
  const headerBounds = await header.boundingBox();
  assert.ok(headerBounds);
  const topControls = await header.getByRole('button').all();
  assert.equal(topControls.length, 4);
  for (const control of topControls) {
    const bounds = await control.boundingBox();
    assert.ok(bounds && bounds.y >= headerBounds.y && bounds.y + bounds.height <= headerBounds.y + headerBounds.height,
      'mobile actions fit vertically inside the header');
  }
  const travel = await byButton(page.locator('.mobile-glance'), /Rời đi 07:15/).boundingBox();
  assert.ok(travel && travel.y + travel.height < 780, 'departure time is above the fold');
  await capture(page, 'mobile');
  await byButton(page, 'Tuần').click();
  const nextDay = page.locator('button[data-action="date"][data-id="2026-11-24"]');
  await nextDay.tap();
  assert.equal(await nextDay.getAttribute('aria-pressed'), 'true');
  assert.match(await bodyText(page), /Lớp UX Research/);
});

test('keyboard selection retains the date across calendar views and restores focus on Escape', async t => {
  const { page } = await open(t);
  await byButton(page, 'Tuần').click();
  const nextDay = page.locator('button[data-action="date"][data-id="2026-11-24"]');
  await nextDay.focus();
  await page.keyboard.press('Enter');
  assert.equal(await nextDay.getAttribute('aria-pressed'), 'true');
  await byButton(page, 'Ngày').click();
  assert.match(await bodyText(page), /Lớp UX Research/);
  const classButton = page.locator('button.agenda-row[data-id="ux-research"]');
  await classButton.focus();
  await page.keyboard.press('Enter');
  const dialog = page.getByRole('dialog');
  await dialog.waitFor();
  await page.keyboard.press('Escape');
  await dialog.waitFor({ state: 'hidden' });
  assert.equal(await classButton.evaluate(element => document.activeElement === element), true);
  await byButton(page, 'Tháng').click();
  assert.equal(await nextDay.getAttribute('aria-pressed'), 'true');
  await byButton(page, /^Chọn ngày,/).click();
  await page.getByLabel('Ngày muốn xem', { exact: true }).fill('2026-12-15');
  await byButton(page, 'Đến ngày').click();
  assert.equal(await page.locator('button[data-action="date"][data-id="2026-12-15"]').getAttribute('aria-pressed'), 'true');
});

test('desktop initial view has accessible names and landmark structure', async t => {
  const { page } = await open(t, { viewport: { width: 1280, height: 960 } });
  const result = await new AxeBuilder({ page }).withRules([
    'aria-allowed-attr', 'aria-required-attr', 'aria-roles', 'button-name', 'label', 'landmark-one-main', 'link-name'
  ]).analyze();
  assert.deepEqual(result.violations.map(({ id, nodes }) => ({ id, nodes: nodes.map(node => node.target) })), []);
});

test('palette and light/dark changes take effect and persist after a reload', async t => {
  const { page } = await open(t, { colorScheme: 'light' });
  const initial = await appearance(page);
  assert.equal(initial.background.toUpperCase(), '#E9F4FA');
  await byButton(page, 'Cài đặt').first().click();
  await byButton(page, /Orchid · Mint/).first().click();
  const alternatePalette = await appearance(page);
  assert.notDeepEqual(alternatePalette, initial);
  assert.equal(alternatePalette.background.toUpperCase(), '#F1EDF9');
  await byButton(page, 'Tối').first().click();
  const dark = await appearance(page);
  assert.notDeepEqual(dark, alternatePalette);
  assert.equal(dark.background.toUpperCase(), '#25142D');
  await capture(page, 'settings-dark');
  await page.reload();
  assert.deepEqual(await appearance(page), dark);
});

test('sample sources keep the successful drafts and preserve the unresolved item across reload', async t => {
  const { page } = await open(t);
  await byButton(page, 'Thêm nguồn').first().click();
  await byButton(page, 'Dùng dữ liệu mẫu').first().click();
  await page.getByText(/mai 7h/i).first().waitFor();
  assert.match(await bodyText(page), /Duyệt bản mẫu với nhóm/);
  await capture(page, 'sample-sources');
  await navigate(page, 'Nguồn');
  const retry = byButton(page, 'Thử lại').first();
  await retry.click();
  await retry.waitFor();
  await page.reload();
  await navigate(page, /Cần duyệt/);
  assert.match(await bodyText(page), /mai 7h/i);
  assert.equal(await page.getByText('Duyệt bản mẫu với nhóm', { exact: true }).count(), 1);
});

test('two images can be staged and manually reviewed while offline', async t => {
  const { page, context } = await open(t);
  await context.setOffline(true);
  await byButton(page, 'Thêm nguồn').first().click();
  const pngs = [
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGPk9/7PgA0wYRUdtBIAEP0BaRM1kVAAAAAASUVORK5CYII=',
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGNMuSPHgA0wYRUdtBIAFhEBbntIvIUAAAAASUVORK5CYII='
  ];
  await page.locator('#source-files').setInputFiles(pngs.map((encoded, index) => ({
    name: `lich-${index + 1}.png`, mimeType: 'image/png', buffer: Buffer.from(encoded, 'base64')
  })));
  assert.equal(await byButton(page.getByRole('dialog'), 'Bỏ tệp').count(), 2);
  await byButton(page, 'Đọc nguồn').first().click();
  const drafts = page.getByRole('navigation', { name: 'Bản nháp' });
  await byButton(drafts, /lich-1\.png/).waitFor();
  await byButton(drafts, /lich-2\.png/).click();
  const evidence = page.getByRole('img', { name: 'Ảnh bằng chứng lich-2.png' });
  await evidence.waitFor();
  assert.equal(await evidence.evaluate(image => image.naturalWidth), 8);
  await page.getByLabel('Tên mục', { exact: true }).fill('Hẹn nhập từ ảnh khi ngoại tuyến');
  await page.getByLabel('Ngày', { exact: true }).fill('2026-11-27');
  await page.getByLabel('Bắt đầu', { exact: true }).fill('11:00');
  await page.getByLabel('Kết thúc', { exact: true }).fill('12:00');
  await byButton(page, 'Xác nhận').first().click();
  assert.match(await bodyText(page), /Đã xác nhận/i);
  await byButton(drafts, /lich-1\.png/).waitFor();
  await context.setOffline(false);
  await page.reload();
  await navigate(page, 'Lịch');
  await byButton(page, 'Tuần').click();
  assert.match(await bodyText(page), /Hẹn nhập từ ảnh khi ngoại tuyến/);
});

test('changed ICS data has evidence and preserves a meeting location changed by the user', async t => {
  const { page } = await open(t);
  const url = 'https://calendar.example.test/course.ics';
  const title = 'Buổi thực hành có cập nhật';
  let revision = 1;
  await page.route(url, route => route.fulfill({
    contentType: 'text/calendar',
    headers: { 'Access-Control-Allow-Origin': '*' },
    body: [
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'BEGIN:VEVENT', 'UID:course-123', `SUMMARY:${title}`, `SEQUENCE:${revision}`,
      `DTSTART;TZID=Asia/Ho_Chi_Minh:${revision === 1 ? '20261125T100000' : '20261125T103000'}`,
      `DTEND;TZID=Asia/Ho_Chi_Minh:${revision === 1 ? '20261125T110000' : '20261125T113000'}`,
      `LOCATION:${revision === 1 ? 'Phòng A1' : 'Phòng B2'}`, 'END:VEVENT', 'END:VCALENDAR'
    ].join('\r\n')
  }));
  await byButton(page, 'Thêm nguồn').first().click();
  await page.getByLabel(/Link lịch/).fill(url);
  await byButton(page, 'Đọc nguồn').first().click();
  await page.getByText(title, { exact: true }).first().waitFor();
  const location = page.getByLabel('Địa điểm', { exact: true });
  await location.fill('Địa điểm tự chọn');
  await byButton(page, 'Xác nhận').first().click();

  revision = 2;
  await navigate(page, 'Nguồn');
  await byButton(page, 'Kiểm tra lại').first().click();
  await navigate(page, /Cần duyệt/);
  await page.getByText(/Nguồn đã đổi/i).first().waitFor();
  assert.match(await bodyText(page), /10:30/);
  assert.match(await bodyText(page), /Địa điểm tự chọn/);
  assert.equal(await location.inputValue(), 'Địa điểm tự chọn');
  await capture(page, 'source-revision');
  await byButton(page, 'Xác nhận thay đổi').first().click();
  await page.reload();
  await navigate(page, /Cần duyệt/);
  assert.doesNotMatch(await bodyText(page), /Nguồn đã đổi/i);
});

test('planning preview applies, undoes and exports a schedulable task after reload', async t => {
  const { page } = await open(t);
  await byButton(page, 'Xếp việc').first().click();
  const preview = page.getByRole('dialog', { name: 'Xem trước kế hoạch' });
  assert.match(await preview.innerText(), /Viết báo cáo Prototype/);
  assert.match(await preview.innerText(), /10:30.*11:30/);
  await byButton(page, 'Áp dụng kế hoạch').first().click();
  const block = page.locator('.week-grid [data-id="prototype-review"]');
  assert.match(await block.innerText(), /10:30/);
  await byButton(page, 'Hoàn tác').click();
  assert.equal(await block.count(), 0);
  await byButton(page, 'Xếp việc').first().click();
  await byButton(page, 'Áp dụng kế hoạch').first().click();
  await capture(page, 'planned');
  await page.reload();
  assert.match(await block.innerText(), /10:30/);
  await byButton(page, 'Cài đặt').first().click();
  const downloaded = page.waitForEvent('download');
  await byButton(page, 'Xuất lịch Fri').click();
  const exportFile = await downloaded;
  assert.equal(exportFile.suggestedFilename(), 'fri-ke-hoach.ics');
  const contents = await fs.readFile(await exportFile.path(), 'utf8');
  assert.match(contents, /SUMMARY:Viết báo cáo Prototype/);
  assert.match(contents, /DTSTART:20261123T033000Z/);
  assert.equal((contents.match(/BEGIN:VEVENT/g) || []).length, 1);
});

test('rescheduling offers a different time and a locked session cannot be rescheduled', async t => {
  const { page } = await open(t);
  const slideBlock = page.locator('.week-grid [data-id="slides"]');
  assert.match(await slideBlock.innerText(), /14:00/);
  await slideBlock.click();
  const dialog = page.getByRole('dialog');
  await byButton(dialog, 'Tìm khung khác').click();
  assert.doesNotMatch(await dialog.innerText(), /14:00–15:00/);
  await byButton(dialog, 'Áp dụng kế hoạch').click();
  assert.doesNotMatch(await slideBlock.innerText(), /14:00/);
  await slideBlock.click();
  await byButton(dialog, 'Khóa phiên').click();
  assert.equal(await byButton(dialog, 'Mở khóa phiên').isVisible(), true);
  assert.equal(await byButton(dialog, 'Tìm khung khác').count(), 0);
});

test('a newer edit in another tab invalidates a previously opened plan preview', async t => {
  const { page, context } = await open(t);
  await byButton(page, 'Xếp việc').first().click();
  const otherTab = await context.newPage();
  await otherTab.goto(appUrl);
  await byButton(otherTab.locator('#top'), 'Tạo mục').click();
  const entryForm = otherTab.getByRole('dialog');
  await entryForm.getByLabel('Tên mục', { exact: true }).fill('Lịch mới từ tab khác');
  await entryForm.getByLabel('Bắt đầu', { exact: true }).fill('10:30');
  await entryForm.getByLabel('Kết thúc', { exact: true }).fill('11:00');
  await byButton(entryForm, 'Tạo mục').click();
  await entryForm.waitFor({ state: 'hidden' });
  const preview = page.getByRole('dialog');
  await byButton(preview, 'Áp dụng kế hoạch').click();
  assert.match(await preview.innerText(), /Lịch đã thay đổi/);
  await byButton(preview, 'Xem đề xuất mới').click();
  assert.match(await preview.innerText(), /11:00.*12:00/);
});

test('widget preview uses the calendar context and can open the correct trip', async t => {
  const { page } = await open(t);
  await byButton(page, 'Widget').first().click();
  const small = page.locator('.widget-host').filter({ hasText: 'iPhone · Nhỏ' }).getByRole('button');
  const medium = page.locator('.widget-host').filter({ hasText: 'iPhone · Vừa' }).getByRole('button');
  const lock = page.locator('.widget-host').filter({ hasText: 'iPhone · Màn hình khóa' }).getByRole('button');
  assert.match(await small.innerText(), /07:15/);
  assert.match(await medium.innerText(), /Tiến độ 2\/5/i);
  assert.match(await lock.innerText(), /Chi tiết ẩn/);
  assert.doesNotMatch(await lock.innerText(), /Trường/);
  await page.getByLabel('Ẩn chi tiết ở màn hình khóa', { exact: true }).uncheck();
  assert.match(await lock.innerText(), /Trường/);
  await page.getByLabel('Màu nhấn hệ thống', { exact: true }).check();
  assert.match(await small.getAttribute('class'), /tinted/);
  await capture(page, 'widgets');
  await small.click();
  const details = page.getByRole('dialog');
  assert.match(await details.innerText(), /Đến trường/);
  assert.match(await details.innerText(), /07:15/);
  assert.equal(new URL(page.url()).hash, '#calendar/item/school-trip');
  await page.reload();
  assert.match(await details.innerText(), /Đến trường/);
});
