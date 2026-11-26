'use strict';
const pages = Array.from(document.querySelectorAll('main section'));
const next = document.getElementById('next');
const back = document.getElementById('back');
const exit = document.getElementById('exit');
const reviewing = location.hash === '#review';
let page = 0;

// The alternative Electron build for Mac has no chat agent of its own.
if (window.friDesktop?.platform === 'darwin') {
  const note = document.createElement('p');
  note.textContent = 'Trên Mac, hãy mở bản FRI native và vào File → Thư ký lịch… Các bước bên dưới dành cho Windows và Linux.';
  pages[1].querySelector('h1').after(note);
}
function showPage() {
  pages.forEach((section, index) => { section.hidden = index !== page; });
  document.getElementById('progress').textContent = 'Phần ' + (page + 1) + ' / ' + pages.length;
  back.hidden = page === 0;
  next.textContent = page < pages.length - 1 ? 'Tiếp tục' : reviewing ? 'Xong' : 'Đã đọc · Vào FRI';
  pages[page].querySelector('h1').focus();
  window.scrollTo(0, 0);
}
back.addEventListener('click', () => { if (page > 0) { page--; showPage(); } });
next.addEventListener('click', async () => {
  if (page < pages.length - 1) { page++; showPage(); return; }
  if (reviewing) { window.close(); return; }
  next.disabled = true;
  try { await window.friDesktop.finishUsageGuide(); }
  catch { next.disabled = false; document.getElementById('error').textContent = 'Chưa lưu được trạng thái đã đọc. Hãy thử lại.'; }
});
exit.hidden = false;
exit.textContent = reviewing ? 'Đóng' : 'Đóng cửa sổ';
exit.addEventListener('click', () => window.close());
if (reviewing) document.addEventListener('keydown', event => { if (event.key === 'Escape') window.close(); });
showPage();
