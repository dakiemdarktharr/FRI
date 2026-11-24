// Capture the shipping desktop renderer at controlled noise times, after its camera settles.
// FRI_PLAYWRIGHT_MODULE may point to an installed Playwright module; no package changes required.
// node CaptureGradientReference.mjs <FRI-liquid-glass.html> <output-directory>
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
const { chromium } = await import(process.env.FRI_PLAYWRIGHT_MODULE || 'playwright');
const [source, output] = process.argv.slice(2);
if (!source || !output) throw new Error('Expected reference HTML and output directory');
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true, ...(process.env.FRI_CHROMIUM ? { executablePath: process.env.FRI_CHROMIUM } : {}) });
try {
  const page = await browser.newPage({ viewport: { width: 1200, height: 1000 } });
  await page.addInitScript(() => {
    window.friProbeTime = 6;
    window.friProbeUniforms = {};
    const names = new WeakMap(), prototype = WebGL2RenderingContext.prototype;
    const getLocation = prototype.getUniformLocation;
    prototype.getUniformLocation = function (program, name) {
      const location = getLocation.call(this, program, name);
      if (location) names.set(location, name);
      return location;
    };
    for (const method of ['uniformMatrix4fv', 'uniform1f']) {
      const original = prototype[method];
      prototype[method] = function (location, ...args) {
        const name = names.get(location);
        // Freeze noise only. Camera controls must finish their normal transition.
        if (name === 'uTime') args[0] = window.friProbeTime;
        if (name) window.friProbeUniforms[name] = method === 'uniformMatrix4fv' ? Array.from(args[1]) : args[0];
        return original.call(this, location, ...args);
      };
    }
  });
  await page.goto(pathToFileURL(resolve(source)).href);
  await page.addStyleTag({ content: '.sidebar-content{visibility:hidden!important}.sidebar{border-radius:0!important}' });
  await page.evaluate(() => window.renderSidebarGradient(true, false));
  await page.waitForTimeout(3500);
  const captures = [];
  for (const [width, height] of [[258, 698], [235, 740]]) {
    await page.locator('.sidebar').evaluate((element, size) => {
      element.style.width = `${size[0]}px`; element.style.height = `${size[1]}px`;
    }, [width, height]);
    await page.waitForTimeout(300);
    for (const time of [6, 18, 42]) {
      await page.evaluate(time => { window.friProbeTime = time; }, time);
      await page.waitForTimeout(150);
      const name = `desktop-${width}x${height}-t${time}.png`;
      await page.locator('#shader').screenshot({ path: join(output, name) });
      captures.push({ name, width, height, time, uniforms: await page.evaluate(() => window.friProbeUniforms) });
    }
  }
  await writeFile(join(output, 'reference.json'), JSON.stringify(captures, null, 2));
  console.log(`Captured ${captures.length} desktop frames`);
} finally { await browser.close(); }
