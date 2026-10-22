# 워치 스크린샷에서 화면 영역(screen)과 주황·진한 빨강 덩어리 경계를 JSON 으로 낸다.
# 사용: python3 measure.py <이미지>...   (시안의 SCR · TAP 좌표를 새로 잴 때)
import sys, json
from collections import deque
from PIL import Image
out = {}
for path in sys.argv[1:]:
    im = Image.open(path).convert('RGB'); W, H = im.size; px = im.load()
    br = lambda p: max(p)
    # 화면 중앙 근처의 검은 픽셀에서 출발해 어두운 영역을 채운다 (티타늄 테두리에서 멈춘다)
    seed = None
    for dy in range(0, H // 4):
        for x in range(W * 3 // 10, W * 7 // 10):
            y = H // 2 + dy
            if br(px[x, y]) < 20: seed = (x, y); break
        if seed: break
    seen = bytearray(W * H); q = deque([seed]); seen[seed[1] * W + seed[0]] = 1
    minx, miny, maxx, maxy = W, H, 0, 0
    while q:
        x, y = q.popleft()
        minx, miny, maxx, maxy = min(minx, x), min(miny, y), max(maxx, x), max(maxy, y)
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < W and 0 <= ny < H and not seen[ny*W+nx] and br(px[nx, ny]) < 45:
                seen[ny*W+nx] = 1; q.append((nx, ny))
    # 화면 안 색 덩어리 (주황·빨강·노랑·파랑) 경계
    def box(pred):
        xs, ys = [], []
        for y in range(miny, maxy + 1):
            for x in range(minx, maxx + 1):
                if pred(px[x, y]): xs.append(x); ys.append(y)
        return [min(xs), min(ys), max(xs), max(ys)] if xs else None
    orange = box(lambda p: p[0] > 200 and 110 < p[1] < 175 and p[2] < 60)
    darkred = box(lambda p: 60 < p[0] < 110 and p[1] < 40 and p[2] < 40)
    out[path.split('/')[-1]] = {'size': [W, H], 'screen': [minx, miny, maxx, maxy], 'orange': orange, 'darkred': darkred}
print(json.dumps(out, indent=1))
