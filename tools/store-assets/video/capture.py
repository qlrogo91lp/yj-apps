# 로컬 서버로 render.html 을 띄우고, 헤드리스 크롬이 POST 하는 프레임 PNG 를 <작업 폴더>/frames/ 에 받는다.
# 사용: python3 capture.py <작업 폴더> [크롬 경로] [프로필 폴더]
import http.server, os, sys, threading, subprocess, time, urllib.parse
ROOT = sys.argv[1]
CHROME = sys.argv[2] if len(sys.argv) > 2 else '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
PROFILE = sys.argv[3] if len(sys.argv) > 3 else os.path.join(ROOT, '.chrome-profile')
OUT = os.path.join(ROOT, 'frames'); os.makedirs(OUT, exist_ok=True)
state = {'done': False, 'error': None, 'count': 0}
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=ROOT, **k)
    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        data = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        if u.path == '/frame':
            i = int(urllib.parse.parse_qs(u.query)['i'][0])
            with open(os.path.join(OUT, f'f{i:05d}.png'), 'wb') as f: f.write(data)
            state['count'] += 1
        elif u.path == '/done': state['done'] = True
        elif u.path == '/error': state['error'] = data.decode(errors='replace'); state['done'] = True
        self.send_response(204); self.end_headers()
    def log_message(self, *a): pass
srv = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()
chrome = subprocess.Popen([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', f'--user-data-dir={PROFILE}',
                           '--window-size=800,600', f'http://127.0.0.1:{port}/render.html'],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
t0 = time.time()
while not state['done'] and time.time() - t0 < 540:
    time.sleep(0.5)
chrome.terminate(); srv.shutdown()
print('frames', state['count'], 'error', state['error'], 'secs', round(time.time() - t0, 1))
