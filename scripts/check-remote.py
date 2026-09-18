#!/usr/bin/env python3
"""Check a running local display server using a private link file, without logging credentials."""
import argparse
import http.client
import json
from pathlib import Path
from urllib.parse import urlsplit, parse_qs

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('link_file', type=Path, help='File containing the private link copied from Sillage Settings')
args = parser.parse_args()
url = urlsplit(args.link_file.read_text().strip())
assert url.scheme == 'http' and url.hostname and url.port
key = parse_qs(url.fragment)['join'][0]

def request(method, path, body=None, headers=None):
    connection = http.client.HTTPConnection(url.hostname, url.port, timeout=5)
    connection.request(method, path, body=body, headers=headers or {})
    response = connection.getresponse()
    result = response.status, dict(response.getheaders()), response.read()
    connection.close()
    return result

assert request('GET', '/api/stream')[0] == 401
assert request('GET', '/api/session')[0] == 401
assert request('GET', '/', headers={'Origin': 'https://unrelated.example'})[0] == 403
assert request('GET', '/', headers={'Host': 'unrelated.example'})[0] == 403
assert request('GET', '/../../../etc/passwd')[0] == 404
assert request('POST', '/api/pair', json.dumps({'key': 'wrong'}), {'Content-Type': 'application/json'})[0] == 403
for asset in ['/', '/app.js', '/renderer.js', '/styles.css', '/locales/en.json', '/locales/fr.json', '/manifest.webmanifest', '/sw.js', '/icon.svg', '/icon-192.png', '/icon-512.png', '/apple-touch-icon.png']:
    status, headers, data = request('GET', asset)
    assert status == 200 and data, (asset, status)
    assert headers.get('X-Content-Type-Options') == 'nosniff'
status, headers, _ = request('POST', '/api/pair', json.dumps({'key': key}), {'Content-Type': 'application/json'})
assert status == 204
cookie = headers['Set-Cookie'].split(';')[0]
assert 'HttpOnly' in headers['Set-Cookie'] and 'SameSite=Strict' in headers['Set-Cookie']
assert request('GET', '/api/session', headers={'Cookie': cookie})[0] == 204
connection = http.client.HTTPConnection(url.hostname, url.port, timeout=5)
connection.request('GET', '/api/stream', headers={'Cookie': cookie})
response = connection.getresponse()
assert response.status == 200 and response.getheader('Content-Type') == 'text/event-stream'
frames = []
while len(frames) < 10:
    line = response.readline()
    assert line, 'Unexpected stream end'
    if line.startswith(b'data: '):
        frames.append(json.loads(line[6:]))
connection.close()
assert all(a['sequence'] < b['sequence'] for a, b in zip(frames, frames[1:]))
assert all(p['version'] == 1 and len(p['phase']) <= 256 and len(p['waveform']) <= 256 for p in frames)
assert all(len(p['levels']) == 2 and len(p['spectrum']) == 160 for p in frames)
print('PASS: packaged assets, authentication, session cookie, origin/host checks, traversal rejection, and 10 bounded live frames.')
print('Source:', frames[-1]['presentation']['source'], '| Max JSON bytes:', max(len(json.dumps(p, separators=(',', ':'))) for p in frames))
