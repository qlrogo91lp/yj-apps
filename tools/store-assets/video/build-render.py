# 시안 HTML 에서 프레임 추출용 페이지(render.html)를 만든다. 앱·자리가 바뀌어도 이 파일은 고치지 않는다 — 값은 인자로 받는다.
#
# 사용:
#   python3 build-render.py <시안.html> <작업 폴더> --scene <장면 함수> --size <가로x세로> --seconds <길이>
#                           [--fps 30] [--lang en] [--images <이미지>...]
#
# 시안 HTML 의 약속
#   - 스크립트 안에 `const scenes = { 장면함수, ... };` 선언이 있다
#   - 장면 함수는 (ctx, W, H, t초, lang) 을 받아 한 프레임을 그린다. 같은 t 면 같은 그림이어야 한다
#   - 이미지를 쓰면 `const IMG = {...}` 에 Image 를 모으고, 경로는 `../inputs/` 로 시작한다
#     → --images 로 넘긴 파일을 작업 폴더 files/ 에 복사하고 경로를 files/ 로 바꾼다
#
# 예: 헤더 (21:9)
#   python3 video/build-render.py mockups/ralli-header.html out/ralli-header --scene ralliHeader --size 3840x1646 --seconds 8.8
import argparse, re, shutil
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument('mockup'); ap.add_argument('work')
ap.add_argument('--scene', required=True)
ap.add_argument('--size', required=True, help='예: 3840x1646 (헤더) · 2880x1920 (검색 결과)')
ap.add_argument('--seconds', type=float, required=True, help='한 바퀴 길이. 장면의 반복 주기와 같아야 이음매가 없다')
ap.add_argument('--fps', type=int, default=30)
ap.add_argument('--lang', default='en')
ap.add_argument('--images', nargs='*', default=[])
a = ap.parse_args()

W, H = (int(v) for v in a.size.lower().split('x'))
frames = round(a.fps * a.seconds)
assert abs(frames - a.fps * a.seconds) < 1e-6, f'{a.seconds}초 × {a.fps}fps 가 정수 프레임이 아니다'

src = Path(a.mockup).read_text()
scripts = re.findall(r'<script>(.*?)</script>', src, re.S)
script = next((s for s in scripts if re.search(r'const scenes = \{[^}]*\};', s)), None)
assert script, '시안에 `const scenes = { ... };` 선언이 없다'
decl = re.search(r'const scenes = \{[^}]*\};', script).group(0)
assert re.search(rf'\b{re.escape(a.scene)}\b', decl), f'scenes 에 {a.scene} 가 없다: {decl}'
script = script.replace(decl, decl + f" window.__scene = scenes['{a.scene}'];"
                        " window.__IMG = (typeof IMG !== 'undefined') ? IMG : {};")
script = script.replace('../inputs/', 'files/')
# 화면 표시용 캔버스 루프는 render.html 에 캔버스가 없어 아무것도 그리지 않는다

driver = f"""
(async function () {{
  const W = {W}, H = {H}, FPS = {a.fps}, N = {frames};
  const c = document.getElementById('out'); c.width = W; c.height = H;
  const ctx = c.getContext('2d');
  await Promise.all(Object.values(window.__IMG).map(im => im.decode()));
  await document.fonts.ready;
  for (let i = 0; i < N; i++) {{
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W, H);
    window.__scene(ctx, W, H, i / FPS, '{a.lang}'); ctx.restore();
    const blob = await new Promise(r => c.toBlob(r, 'image/png'));
    await fetch('/frame?i=' + i, {{ method: 'POST', body: blob }});
  }}
  await fetch('/done', {{ method: 'POST' }});
}})().catch(e => fetch('/error', {{ method: 'POST', body: String(e && e.stack || e) }}));
"""
html = ('<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#000}</style></head>'
        f'<body><canvas id="out"></canvas><script>{script}</script><script>{driver}</script></body></html>')

work = Path(a.work); work.mkdir(parents=True, exist_ok=True)
(work / 'render.html').write_text(html)
if a.images:
    files = work / 'files'; files.mkdir(exist_ok=True)
    for p in a.images: shutil.copy(p, files / Path(p).name)
print(f'render.html 완료 → {work}  ({a.scene} · {W}x{H} · {a.seconds}s · {frames} 프레임)')
