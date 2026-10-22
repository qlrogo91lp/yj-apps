# 워치 스크린샷 4장의 시계를 요약 화면(result)의 시각 글자로 통일한다.
# 사용: python3 unify-clock.py <입력 폴더> <출력 폴더>
#   입력: watch-{home,workout,control,result}-global.png (3x, 1266x1542)
#   출력: watch-{home,workout,control,result}-416.png
import sys
from PIL import Image
src_dir, out_dir = sys.argv[1], sys.argv[2]
def clock_box(im):
    px = im.load(); xs, ys = [], []
    for y in range(330, 460):
        for x in range(800, 995):
            if min(px[x, y]) > 150: xs.append(x); ys.append(y)
    return min(xs), min(ys), max(xs), max(ys)
ref = Image.open(f'{src_dir}/watch-result-global.png').convert('RGB')
rb = clock_box(ref); m = 4
glyph = ref.crop((rb[0] - m, rb[1] - m, rb[2] + m + 1, rb[3] + m + 1))
print('ref 4:16', rb)
for k in ['home', 'workout', 'control', 'result']:
    im = Image.open(f'{src_dir}/watch-{k}-global.png').convert('RGB')
    if k != 'result':
        b = clock_box(im); print(k, b)
        im.paste((0, 0, 0), (b[0] - m, b[1] - m, b[2] + m + 1, b[3] + m + 1))
        cy = (b[1] + b[3]) // 2; gy = cy - (rb[3] - rb[1]) // 2 - m
        im.paste(glyph, (b[2] + m + 1 - glyph.width, gy))
    im.save(f'{out_dir}/watch-{k}-416.png')
