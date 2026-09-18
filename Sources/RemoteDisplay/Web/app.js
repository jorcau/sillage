import {InstrumentRenderer, VIEWS, THEMES, validPacket, silentPacket} from './renderer.js';
const $ = id => document.getElementById(id);
const saved = (() => { try { return JSON.parse(localStorage.getItem('sillage-display') || '{}'); } catch { return {}; } })();
const options = {view:VIEWS.includes(saved.view)?saved.view:'dashboard',theme:Object.hasOwn(THEMES,saved.theme)?saved.theme:'mint',follow:saved.follow!==false,fps:saved.fps===30?30:60,brightness:1,language:saved.language==='fr'||(!saved.language&&navigator.language.startsWith('fr'))?'fr':'en'};
let strings={}, packet=silentPacket(), received=0, source=null, connected=false, retryTimer=0, attempt=0, lastDraw=0, lastReadout=0, wakeLock=null, installPrompt=null;
// The private key is used once and removed from the address bar before network requests.
let joinKey = new URLSearchParams(location.hash.slice(1)).get('join');
if (location.hash) history.replaceState(null,'',location.pathname);
const renderer = new InstrumentRenderer($('instruments'));
const t = key => strings[key] || key;
function save(){try{localStorage.setItem('sillage-display',JSON.stringify(options));}catch{}}
function connection(state){$('connection').dataset.state=state;$('connection').textContent=t(state);}
function overlay(kind){$('empty').hidden=!kind;if(kind){$('emptyTitle').textContent=t(`${kind}Title`);$('emptyMessage').textContent=t(`${kind}Message`);}}
async function language(){try{strings=await(await fetch(`/locales/${options.language}.json`)).json();}catch{strings={};}document.documentElement.lang=options.language;document.querySelectorAll('[data-i18n]').forEach(el=>el.textContent=t(el.dataset.i18n));$('view').replaceChildren(...VIEWS.map(v=>new Option(t(v),v)));$('theme').replaceChildren(...Object.keys(THEMES).map(v=>new Option(t(v),v)));$('view').value=options.view;$('theme').value=options.theme;$('language').value=options.language;$('follow').checked=options.follow;$('refresh').value=String(options.fps);$('installHint').textContent=t(isSecureContext?'installSecure':'installLocal');$('instruments').setAttribute('aria-label',t('instruments'));connection(connected?'live':'connecting');readout();}
function readout(){const p=packet.presentation;$('viewTitle').textContent=t(options.view);$('source').textContent=t(p.source==='demo'?'demo':p.source==='paused'?'paused':p.source==='waiting'?'waiting':'fromMac');$('sampleRate').textContent=`${(packet.sampleRate/1000).toFixed(1)} kHz`;$('reading').textContent=`L ${packet.levels[0][0].toFixed(1)} · R ${packet.levels[1][0].toFixed(1)} dBFS`;}
function closeStream(){if(source){source.close();source=null;}connected=false;clearTimeout(retryTimer);}
function schedule(){clearTimeout(retryTimer);if(!document.hidden)retryTimer=setTimeout(()=>connect(),2000);}
async function connect(){closeStream();const generation=++attempt;if(document.hidden)return;connection('connecting');
  try{
    if(joinKey){const key=joinKey;joinKey=null;const response=await fetch('/api/pair',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({key}),cache:'no-store'});if(generation!==attempt)return;if(!response.ok){overlay(response.status===429?'busy':'expired');connection('offline');return;}}
    const session=await fetch('/api/session',{cache:'no-store'});if(generation!==attempt||document.hidden)return;
    if(session.status===401||session.status===403){overlay('pair');connection('offline');return;}
    if(!session.ok){overlay('busy');connection('offline');schedule();return;}
    const stream=new EventSource('/api/stream');source=stream;
    stream.onmessage=event=>{if(source!==stream)return;let next;try{next=JSON.parse(event.data);}catch{return;}if(!validPacket(next))return;packet=next;received=performance.now();connected=true;connection('live');overlay(null);if(options.follow){options.view=next.presentation.view;options.theme=next.presentation.theme;$('view').value=options.view;$('theme').value=options.theme;} };
    stream.onerror=()=>{if(source!==stream)return;closeStream();connection('reconnecting');schedule();};
  }catch{if(generation!==attempt)return;connection('offline');overlay('offline');schedule();}
}
async function keepAwake(){if(!('wakeLock' in navigator)||document.hidden||!isSecureContext)return;try{wakeLock=await navigator.wakeLock.request('screen');}catch{}}
function focus(enabled){document.body.classList.toggle('focus',enabled);$('leaveFocus').hidden=!enabled;renderer.key='';if(enabled)keepAwake();else if(wakeLock){wakeLock.release();wakeLock=null;}}
$('settingsButton').onclick=()=>{$('settings').showModal();};$('closeSettings').onclick=()=>{$('settings').close();};
$('focusButton').onclick=()=>focus(true);$('leaveFocus').onclick=()=>focus(false);
$('fullscreenButton').hidden=!document.fullscreenEnabled;
$('fullscreenButton').onclick=async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen();}catch{focus(true);}};
document.addEventListener('fullscreenchange',()=>{$('fullscreenButton').textContent=t(document.fullscreenElement?'exitFullscreen':'fullscreen');keepAwake();});
for(const field of ['view','theme'])$(field).onchange=()=>{options[field]=$(field).value;options.follow=false;$('follow').checked=false;save();readout();};
$('follow').onchange=()=>{options.follow=$('follow').checked;if(options.follow){options.view=packet.presentation.view;options.theme=packet.presentation.theme;$('view').value=options.view;$('theme').value=options.theme;}save();readout();};
$('language').onchange=async()=>{options.language=$('language').value;save();await language();};
$('refresh').onchange=()=>{options.fps=Number($('refresh').value);save();};$('brightness').oninput=()=>{options.brightness=Number($('brightness').value);};$('retry').onclick=()=>connect();
document.addEventListener('visibilitychange',()=>{attempt++;if(document.hidden){closeStream();received=0;packet=silentPacket();renderer.history=[];}else{connect();if(document.body.classList.contains('focus'))keepAwake();}});
window.addEventListener('pagehide',()=>{attempt++;closeStream();});window.addEventListener('pageshow',event=>{if(event.persisted)connect();});window.addEventListener('online',()=>connect());
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();installPrompt=event;$('install').hidden=false;});$('install').onclick=async()=>{if(installPrompt){await installPrompt.prompt();installPrompt=null;$('install').hidden=true;}};
let stale=false;
function animate(now){requestAnimationFrame(animate);if(document.hidden||now-lastDraw<1000/options.fps-1)return;lastDraw=now;
  if(received&&now-received>1800){if(!stale){packet=silentPacket();renderer.history=[];connection('reconnecting');overlay('offline');stale=true;}}else stale=false;
  renderer.draw(packet,options,now);if(now-lastReadout>350){readout();lastReadout=now;}
}
await language();overlay('pair');await connect();requestAnimationFrame(animate);
if('serviceWorker' in navigator&&isSecureContext)navigator.serviceWorker.register('/sw.js').catch(()=>{});
