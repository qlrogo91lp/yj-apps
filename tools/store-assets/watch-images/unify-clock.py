# 워치 스크린샷 여러 장의 시계를 기준 이미지의 시각 글자로 통일한다.
# 화면마다 시계 위치가 달라서(툴바 유무 등) 통째로 덮지 않고, 각 이미지의 시계 자리를 지운 뒤
# 기준 글자를 그 자리에 오른쪽 정렬로 붙인다. 출력 이름은 <원래 이름>-clock.png.
#
# 사용: python3 unify-clock.py --ref <기준 이미지> --out <출력 폴더> <이미지>...
#   [--box x0,y0,x1,y1]  시계를 찾는 영역. 기본값은 피그마 Ultra 테두리 3x 내보내기(1266x1542) 기준
import argparse
from pathlib import Path
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument('--ref', required=True)
ap.add_argument('--out', required=True)
ap.add_argument('--box', default='800,330,995,460')
ap.add_argument('images', nargs='+')
a = ap.parse_args()
bx0, by0, bx1, by1 = (int(v) for v in a.box.split(','))

def clock_box(im):
    px = im.load(); xs, ys = [], []
    for y in range(by0, by1):
        for x in range(bx0, bx1):
            if min(px[x, y]) > 150: xs.append(x); ys.append(y)
    assert xs, f'시계를 못 찾았다 (영역 {a.box})'
    return min(xs), min(ys), max(xs), max(ys)

ref = Image.open(a.ref).convert('RGB')
rb = clock_box(ref); m = 4
glyph = ref.crop((rb[0] - m, rb[1] - m, rb[2] + m + 1, rb[3] + m + 1))
print('기준', Path(a.ref).name, rb)
out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
for p in a.images:
    im = Image.open(p).convert('RGB')
    if Path(p).resolve() != Path(a.ref).resolve():
        b = clock_box(im); print(Path(p).name, b)
        im.paste((0, 0, 0), (b[0] - m, b[1] - m, b[2] + m + 1, b[3] + m + 1))
        cy = (b[1] + b[3]) // 2
        im.paste(glyph, (b[2] + m + 1 - glyph.width, cy - (rb[3] - rb[1]) // 2 - m))
    im.save(out / f'{Path(p).stem}-clock.png')
