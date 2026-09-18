import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {validPacket, silentPacket, vuFraction, VIEWS, THEMES} from '../../Sources/RemoteDisplay/Web/renderer.js';

test('rejects malformed, nonfinite, oversized, and unknown protocol frames', () => {
  const frame=silentPacket(); assert.equal(validPacket(frame),true);
  for(const patch of [{version:2},{sequence:-1},{levels:[null,null]},{levels:[[Infinity,0,0,0],[0,0,0,0]]},{phase:Array(257).fill([0,0])},{spectrum:[NaN]},{waveform:[[0,0,0]]},{correlation:2},{presentation:{view:'unknown',theme:'mint',source:'demo'}}]) {
    assert.equal(validPacket({...frame,...patch}),false);
  }
  assert.equal(validPacket(null),false);
});
test('VU reference and stops match the Mac renderer',()=>{
  assert.equal(vuFraction(-90),0);assert.equal(vuFraction(-15),1);assert.equal(vuFraction(0),1);
  assert.ok(Math.abs(vuFraction(-18)-Math.pow(10,-3/20))<1e-9);
  assert.ok(vuFraction(-24)<vuFraction(-18));
});
test('English and French cover all controls, views and themes',()=>{
  const en=JSON.parse(fs.readFileSync(new URL('../../Sources/RemoteDisplay/Web/locales/en.json',import.meta.url)));
  const fr=JSON.parse(fs.readFileSync(new URL('../../Sources/RemoteDisplay/Web/locales/fr.json',import.meta.url)));
  assert.deepEqual(Object.keys(en).sort(),Object.keys(fr).sort());
  for(const key of [...VIEWS,...Object.keys(THEMES)]) { assert.ok(en[key]);assert.ok(fr[key]); }
  const html=fs.readFileSync(new URL('../../Sources/RemoteDisplay/Web/index.html',import.meta.url),'utf8');
  for(const [,key] of html.matchAll(/data-i18n="([^"]+)"/g)) assert.ok(en[key]);
});
