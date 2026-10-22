# 시안 HTML 에서 프레임 추출용 페이지(render.html)를 만든다.
# 사용: python3 build-render.py <시안.html> <작업 폴더> [lang=en] [fps=30] [seconds=12]
#   작업 폴더에 render.html 과 files/(워치 이미지)를 만든다. 이미지는 시안 옆 ../inputs/ 에서 가져온다.
import re, shutil, sys
from pathlib import Path

mock, work = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
lang = sys.argv[3] if len(sys.argv) > 3 else 'en'
fps = int(sys.argv[4]) if len(sys.argv) > 4 else 30
secs = int(sys.argv[5]) if len(sys.argv) > 5 else 12

src = mock.read_text()
script = re.search(r'<script>(.*)</script>', src, re.S).group(1)
hook = 'const scenes = { haruchiSearch3 };'
assert hook in script, '시안에 scenes 선언이 없다'
script = script.replace(hook, hook + ' window.__scene = haruchiSearch3; window.__IMG = IMG;')
script = script.replace('../inputs/', 'files/')

driver = f"""
(async function () {{
  const W = 2880, H = 1920, FPS = {fps}, N = FPS * {secs};
  const c = document.getElementById('out'); c.width = W; c.height = H;
  const ctx = c.getContext('2d');
  await Promise.all(Object.values(window.__IMG).map(im => im.decode()));
  await document.fonts.ready;
  for (let i = 0; i < N; i++) {{
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H);
    window.__scene(ctx, W, H, i / FPS, '{lang}'); ctx.restore();
    const blob = await new Promise(r => c.toBlob(r, 'image/png'));
    await fetch('/frame?i=' + i, {{ method: 'POST', body: blob }});
  }}
  await fetch('/done', {{ method: 'POST' }});
}})().catch(e => fetch('/error', {{ method: 'POST', body: String(e && e.stack || e) }}));
"""
html = ('<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#000}</style></head>'
        f'<body><canvas id="out"></canvas><script>{script}</script><script>{driver}</script></body></html>')

work.mkdir(parents=True, exist_ok=True)
(work / 'render.html').write_text(html)
files = work / 'files'; files.mkdir(exist_ok=True)
inputs = mock.parent.parent / 'inputs'
imgs = list(inputs.glob('watch-*-416.png'))
assert len(imgs) == 4, f'{inputs} 에 watch-*-416.png 4장이 필요하다 (지금 {len(imgs)}장)'
for p in imgs: shutil.copy(p, files / p.name)
print('render.html 완료 →', work)
