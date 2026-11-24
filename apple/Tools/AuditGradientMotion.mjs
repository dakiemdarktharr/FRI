// Observe the shipping desktop's real clock when motion is toggled; no uniform overrides.
// node AuditGradientMotion.mjs <FRI-liquid-glass.html> <output.json>
import { writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const { chromium } = await import(process.env.FRI_PLAYWRIGHT_MODULE || 'playwright');
const [source, output] = process.argv.slice(2);
if (!source || !output) throw new Error('Expected reference HTML and output JSON');
const browser = await chromium.launch({ headless: true,
  ...(process.env.FRI_CHROMIUM ? { executablePath: process.env.FRI_CHROMIUM } : {}) });
try {
  const page = await browser.newPage({ viewport: { width: 1200, height: 800 } });
  await page.addInitScript(() => {
    window.friMotionUniforms = {};
    const names = new WeakMap(), prototype = WebGL2RenderingContext.prototype;
    const getLocation = prototype.getUniformLocation;
    prototype.getUniformLocation = function (program, name) {
      const location = getLocation.call(this, program, name);
      if (location) names.set(location, name);
      return location;
    };
    for (const method of ['uniform1f', 'uniformMatrix4fv']) {
      const original = prototype[method];
      prototype[method] = function (location, ...args) {
        const name = names.get(location);
        if (name === 'uTime' || name === 'modelViewMatrix') {
          window.friMotionUniforms[name] = method === 'uniformMatrix4fv' ? Array.from(args[1]) : args[0];
        }
        return original.call(this, location, ...args);
      };
    }
  });
  await page.goto(pathToFileURL(resolve(source)).href);
  await page.waitForFunction(() => typeof window.renderSidebarGradient === 'function');
  const cycles = [];
  for (let cycle = 0; cycle < 3; cycle++) {
    await page.evaluate(() => {
      window.friMotionUniforms = {};
      window.renderSidebarGradient(true, true);
    });
    await page.waitForTimeout(2500);
    const paused = await page.evaluate(() => window.friMotionUniforms);
    await page.evaluate(() => {
      window.friMotionUniforms = {};
      window.renderSidebarGradient(true, false);
    });
    await page.waitForTimeout(250);
    const restarted = await page.evaluate(() => window.friMotionUniforms);
    await page.waitForTimeout(2000);
    const moving = await page.evaluate(() => window.friMotionUniforms);
    cycles.push({ cycle, paused, restarted, moving });
  }
  await writeFile(output, JSON.stringify(cycles, null, 2) + '\n');
  for (const { paused, restarted, moving } of cycles) {
    if (paused.uTime !== 6 || !(restarted.uTime >= 0 && restarted.uTime < 1) || !(moving.uTime > 1.5)) {
      throw new Error('Desktop motion cycle did not reach the expected states; inspect captured uniforms');
    }
  }
  console.log('Three desktop motion cycles: paused time 6; enabled clock restarts and advances.');
} finally {
  await browser.close();
}
