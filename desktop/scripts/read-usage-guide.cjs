// Shared by UI and installer probes, including probes against older builds.
async function readUsageGuide(page) {
  await page.waitForURL(url => url.pathname.endsWith('/usage-guide.html') || url.href === 'app://fri/index.html');
  if (!new URL(page.url()).pathname.endsWith('/usage-guide.html')) return;
  if (await page.locator('#skip').count()) {
    await page.locator('#skip').click();
    await page.waitForURL('app://fri/index.html');
    return;
  }
  for (let pageNumber = 1; pageNumber <= 2; pageNumber++) {
    await page.getByRole('button', {name: 'Tiếp tục'}).click();
  }
  await page.getByRole('button', {name: 'Đã đọc · Vào FRI'}).click();
  await page.waitForURL('app://fri/index.html');
}
module.exports = {readUsageGuide};
