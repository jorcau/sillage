export const VIEWS = ['dashboard', 'meters', 'spectrum', 'stereo', 'analog', 'studioBlue', 'vintageConsole', 'crtWaveform', 'crtStereo', 'broadcastPPM', 'hifiRack'];
export const THEMES = {
  mint: ['#7adeba', '#7adeba'], aurora: ['#6b83ff','#48d6e8','#7ee3ad','#e2f3a0'], ember: ['#ef668f','#ff865b','#ffc45c','#fff1ad'],
  twilight: ['#5fa2ff','#a085f2','#ee8abe','#ffc1a6'], prism: ['#7297ff','#54d7ea','#92e39d','#f4de77','#f68da7'],
  lagoon: ['#f0bf80','#7ddcc2','#54bbda','#938aeb'], thermal: ['#5675f0','#48cbcd','#bde879','#ffb35f','#f06a86'],
  neon: ['#575cce','#9674eb','#e47ccd','#ffadb9','#ffe3c0'], alpine: ['#277385','#51b8ae','#9fe3c3','#dff4e1']
};
export const clamp = (n, lo = 0, hi = 1) => Math.max(lo, Math.min(hi, Number.isFinite(n) ? n : lo));
export const vuFraction = db => db <= -89 ? 0 : clamp(Math.pow(10, (db + 15) / 20));
const boundedArray = (v, max, low, high) => Array.isArray(v) && v.length <= max && v.every(n => Number.isFinite(n) && n >= low && n <= high);
export function validPacket(p) {
  return !!p && p.version === 1 && Number.isSafeInteger(p.sequence) && p.sequence >= 0 &&
    p.presentation && VIEWS.includes(p.presentation.view) && Object.hasOwn(THEMES, p.presentation.theme) &&
    ['system','demo','paused','waiting'].includes(p.presentation.source) &&
    Number.isFinite(p.sampleRate) && p.sampleRate > 0 && Number.isFinite(p.waveformMS) && p.waveformMS > 0 && p.waveformMS <= 1000 &&
    Number.isFinite(p.correlation) && Math.abs(p.correlation) <= 1 &&
    Array.isArray(p.levels) && p.levels.length === 2 && p.levels.every(v => boundedArray(v, 4, -90, 12) && v.length === 4) &&
    Array.isArray(p.clipped) && p.clipped.length === 2 && p.clipped.every(v => typeof v === 'boolean') &&
    boundedArray(p.spectrum, 160, -90, 0) && boundedArray(p.hold, 160, -90, 0) &&
    Array.isArray(p.phase) && p.phase.length <= 256 && p.phase.every(v => boundedArray(v, 2, -1, 1) && v.length === 2) &&
    Array.isArray(p.waveform) && p.waveform.length <= 256 && p.waveform.every(v => boundedArray(v, 4, -1, 1) && v.length === 4);
}
export function silentPacket() {
  return {version:1,sequence:0,presentation:{view:'dashboard',theme:'mint',source:'paused'},sampleRate:48000,levels:[[-90,-90,-90,-90],[-90,-90,-90,-90]],clipped:[false,false],spectrum:Array(160).fill(-90),hold:Array(160).fill(-90),phase:[],waveform:[],waveformMS:20,correlation:0};
}
function text(c, value, x, y, size=11, color='#89968e', align='center') {
  c.fillStyle=color; c.font=`${size}px ui-monospace, SFMono-Regular, Menlo, monospace`; c.textAlign=align; c.textBaseline='middle'; c.fillText(value,x,y);
}
function line(c,x1,y1,x2,y2,color,width=1) { c.strokeStyle=color;c.lineWidth=width;c.beginPath();c.moveTo(x1,y1);c.lineTo(x2,y2);c.stroke(); }
function gradient(c,x,y,w,h,colors,horizontal=false) { const g=c.createLinearGradient(x,y+h,horizontal?x+w:x,horizontal?y+h:y);colors.forEach((color,i)=>g.addColorStop(i/(colors.length-1),color));return g; }
function panel(c,r,bright=false,wood=false) {
  const {x,y,w,h}=r;
  c.fillStyle=gradient(c,x,y,w,h,bright?['#535653','#aaaaa3','#6d716c','#b0b3ab']:['#101412','#222723','#141a16','#343934']);c.fillRect(x,y,w,h);
  c.strokeStyle=bright?'#b1b7af':'#424b44';c.strokeRect(x+.5,y+.5,w-1,h-1);
  c.save();c.beginPath();c.rect(x,y,w,h);c.clip();
  for(let i=0;i<100;i++)line(c,x,y+i*h/100,x+w,y+i*h/100,i%3?'#00000013':'#ffffff12',.5);
  if(wood)for(const left of [x,x+w-10]){c.fillStyle=gradient(c,left,y,10,h,['#271209','#713d1c','#35190c']);c.fillRect(left,y,10,h);for(let i=1;i<8;i++)line(c,left+i*1.2,y,left+i*1.2+Math.sin(i),y+h,'#0004',.6);}
  c.restore();
  for(const sx of [x+7,x+w-7])for(const sy of [y+7,y+h-7]){const g=c.createRadialGradient(sx-1,sy-1,0,sx,sy,3);g.addColorStop(0,'#969d96');g.addColorStop(1,'#010301');c.fillStyle=g;c.beginPath();c.arc(sx,sy,3,0,Math.PI*2);c.fill();line(c,sx-1.5,sy+1,sx+1.5,sy-1,'#000',1);}
}
function lamp(c,x,y,on) {c.fillStyle='#020403';c.beginPath();c.arc(x,y,5,0,7);c.fill();c.save();c.shadowColor='#ff544e';c.shadowBlur=on?12:0;c.fillStyle=on?'#ff6559':'#49231f';c.beginPath();c.arc(x,y,3,0,7);c.fill();c.restore();c.fillStyle='#fff6';c.fillRect(x-1.5,y-1.5,1.5,1);}
function dialGeometry(r){return {x:r.x+8,y:r.y+8,w:r.w-16,h:r.h-16};}
function dialPoint(r, fraction, radius=1) { const a=(-48+96*fraction)*Math.PI/180;return {x:r.x+r.w/2+Math.sin(a)*r.w*.55*radius,y:r.y+r.h*.94-Math.cos(a)*r.h*.78*radius}; }
function dialFace(c,r,style,channel) {
  panel(c,r,style==='vintage',style==='vintage'); const f=dialGeometry(r),blue=style==='blue';
  c.fillStyle='#040605';c.fillRect(f.x,f.y,f.w,f.h);
  const p={x:f.x+5,y:f.y+5,w:f.w-10,h:f.h-10};
  c.fillStyle=gradient(c,p.x,p.y,p.w,p.h,blue?['#062848','#0860a7','#142e44']:['#d7bd78','#fff0b6','#88754b']);c.fillRect(p.x,p.y,p.w,p.h);
  const glow=c.createRadialGradient(p.x+p.w*.5,p.y+p.h,0,p.x+p.w*.5,p.y+p.h,p.w*.65);glow.addColorStop(0,blue?'#199fea55':'#fff8c0aa');glow.addColorStop(1,'#ffffff00');c.fillStyle=glow;c.fillRect(p.x,p.y,p.w,p.h);
  const ink=blue?'#caefff':'#332d1c';
  for(const db of [-20,-10,-7,-5,-3,-2,-1,0,1,2,3]){const a=dialPoint(p,vuFraction(db-18),.91),b=dialPoint(p,vuFraction(db-18),1);line(c,a.x,a.y,b.x,b.y,db>0?'#c75b46':ink,db>=0?1.4:1);const t=dialPoint(p,vuFraction(db-18),1.13);text(c,db>0?`+${db}`:String(db),t.x,t.y,Math.max(8,p.w*.033),db>0?'#bd4434':ink);}
  c.beginPath();for(let i=0;i<=100;i++){const v=dialPoint(p,i/100,.96);i?c.lineTo(v.x,v.y):c.moveTo(v.x,v.y);}c.strokeStyle=ink;c.lineWidth=.8;c.stroke();
  text(c,'VU',p.x+p.w*.1,p.y+p.h*.13,Math.max(12,p.w*.06),ink);
  text(c,channel,p.x+p.w/2,p.y+p.h*.72,11,ink);text(c,'S I L L A G E',p.x+p.w/2,p.y+p.h*.84,Math.max(7,p.w*.027),ink);
  c.save();c.beginPath();c.rect(p.x,p.y,p.w,p.h);c.clip();const shade=gradient(c,p.x,p.y,p.w,p.h,['#00000000','#00000000','#00000070']);c.fillStyle=shade;c.fillRect(p.x,p.y,p.w,p.h);c.restore();
  return p;
}
function needle(c,p,db,style,clipped){const tip=dialPoint(p,vuFraction(db),1.05),x=p.x+p.w/2,y=p.y+p.h*.94;c.save();c.shadowColor='#0009';c.shadowBlur=3;c.shadowOffsetX=2;c.shadowOffsetY=2;line(c,x,y,tip.x,tip.y,style==='blue'?'#ecffff':style==='vintage'?'#b52e20':'#33291d',1.8);c.restore();c.fillStyle='#292e29';c.beginPath();c.arc(x,y,4,Math.PI,0);c.fill();lamp(c,p.x+p.w-9,p.y+10,clipped);glass(c,p);}
function glass(c,r){c.save();c.beginPath();c.rect(r.x,r.y,r.w,r.h);c.clip();c.beginPath();c.moveTo(r.x,r.y);c.lineTo(r.x+r.w,r.y);c.lineTo(r.x,r.y+r.h*.42);c.closePath();c.fillStyle=gradient(c,r.x,r.y,r.w,r.h,['#ffffff00','#ffffff20']);c.fill();c.restore();}
function scopeFace(c,r,crt,phase){if(crt)panel(c,r);const p={x:r.x+(crt?13:0),y:r.y+(crt?23:18),w:r.w-(crt?26:0),h:r.h-(crt?36:26)};if(crt){c.fillStyle='#020805';c.fillRect(p.x,p.y,p.w,p.h);c.strokeStyle='#3a433d';c.lineWidth=3;c.strokeRect(p.x,p.y,p.w,p.h);}
  const color=crt?(phase?'#db98311c':'#60c58e1d'):'#586e5e27';
  for(let i=0;i<=8;i++){line(c,p.x+i*p.w/8,p.y,p.x+i*p.w/8,p.y+p.h,color);line(c,p.x,p.y+i*p.h/8,p.x+p.w,p.y+i*p.h/8,color);}
  text(c,phase?'L / R · CORRELATION':'L / R · ±1 FS',r.x+8,r.y+9,8,'#8c9b90','left');return p;}
function waveform(c,r,p,color,glow){c.save();c.beginPath();c.rect(r.x,r.y,r.w,r.h);c.clip();c.strokeStyle=color;c.lineWidth=1.15;if(glow){c.shadowColor=color;c.shadowBlur=5;}for(let ch=0;ch<2;ch++){c.beginPath();p.waveform.forEach((v,i)=>{const x=r.x+i/(p.waveform.length-1||1)*r.w,center=r.y+r.h*(ch?.74:.26),y=center-(v[ch*2]+v[ch*2+1])*.5*r.h*.21;i?c.lineTo(x,y):c.moveTo(x,y);if(v[ch*2+1]-v[ch*2]>.01){c.moveTo(x,center-v[ch*2]*r.h*.21);c.lineTo(x,center-v[ch*2+1]*r.h*.21);c.moveTo(x,y);}});c.stroke();}c.restore();}
function phaseTrace(c,r,p,color,glow){const size=Math.min(r.w,r.h)*.90;c.save();c.beginPath();c.rect(r.x,r.y,r.w,r.h);c.clip();c.strokeStyle=color;c.lineWidth=1;if(glow){c.shadowColor=color;c.shadowBlur=5;}c.beginPath();p.phase.forEach((v,i)=>{const x=r.x+r.w/2+v[0]*size*.5,y=r.y+r.h/2-v[1]*size*.5;i?c.lineTo(x,y):c.moveTo(x,y);});c.stroke();c.restore();text(c,`CORR ${p.correlation.toFixed(2)}`,r.x+r.w/2,r.y+r.h-7,9);}
export class InstrumentRenderer {
  constructor(canvas){this.canvas=canvas;this.ctx=canvas.getContext('2d',{alpha:false});this.cache=document.createElement('canvas');this.key='';this.items=[];this.history=[];this.historyTime=0;this.sequence=-1;}
  resize(){const r=this.canvas.getBoundingClientRect();this.w=Math.max(1,r.width);this.h=Math.max(1,r.height);this.dpr=Math.min(window.devicePixelRatio||1,2,Math.sqrt(4_000_000/(this.w*this.h)));const w=Math.round(this.w*this.dpr),h=Math.round(this.h*this.dpr);if(this.canvas.width!==w||this.canvas.height!==h){this.canvas.width=w;this.canvas.height=h;this.cache.width=w;this.cache.height=h;this.key='';}}
  prepare(view,theme){const key=`${view}:${theme}:${this.w}:${this.h}:${this.dpr}`;if(key===this.key)return;this.key=key;this.history=[];this.items=[];const c=this.cache.getContext('2d');c.setTransform(this.dpr,0,0,this.dpr,0,0);c.fillStyle='#000';c.fillRect(0,0,this.w,this.h);const r={x:2,y:2,w:this.w-4,h:this.h-4};
    const item=(type,rect,style='')=>{let plot=rect;if(type==='vu')plot=dialFace(c,rect,style,this.items.filter(i=>i.type==='vu').length?'R':'L');if(type==='scope'||type==='wave')plot=scopeFace(c,rect,!!style,type==='scope');this.items.push({type,r:plot,style});};
    const duo=(rect,style)=>{const stacked=rect.h>rect.w*.9,gap=10;if(stacked){const h=Math.min((rect.h-gap)/2,rect.w*.60),y=rect.y+(rect.h-2*h-gap)/2;item('vu',{x:rect.x,y,w:rect.w,h},style);item('vu',{x:rect.x,y:y+h+gap,w:rect.w,h},style);}else{const w=(rect.w-gap)/2,h=Math.min(rect.h,w*.65),y=rect.y+(rect.h-h)/2;item('vu',{x:rect.x,y,w,h},style);item('vu',{x:rect.x+w+gap,y,w,h},style);}};
    if(view==='dashboard'){if(r.h>r.w){item('fft',{...r,h:r.h*.49});item('scope',{x:r.x,y:r.y+r.h*.55,w:r.w*.57,h:r.h*.43});item('meter',{x:r.x+r.w*.63,y:r.y+r.h*.55,w:r.w*.37,h:r.h*.43});}else{item('fft',{...r,w:r.w*.62});item('scope',{x:r.x+r.w*.66,y:r.y,w:r.w*.21,h:r.h});item('meter',{x:r.x+r.w*.90,y:r.y,w:r.w*.10,h:r.h});}}
    else if(view==='spectrum')item('fft',r);else if(view==='meters')item('meter',r);else if(view==='stereo')item('scope',r);else if(['analog','studioBlue','vintageConsole'].includes(view))duo(r,view==='studioBlue'?'blue':view==='vintageConsole'?'vintage':'classic');
    else if(view==='crtWaveform')item('wave',r,'green');else if(view==='crtStereo')item('scope',r,'amber');else if(view==='broadcastPPM'){panel(c,r);item('ppm',{x:r.x+15,y:r.y+14,w:r.w-30,h:r.h-28});}
    else if(view==='hifiRack'){duo({...r,h:r.h*.61},'vintage');item('wave',{x:r.x,y:r.y+r.h*.65,w:r.w,h:r.h*.33},'green');}
  }
  draw(packet,options,now){this.resize();this.prepare(options.view,options.theme);const c=this.ctx,colors=THEMES[options.theme]||THEMES.mint;c.setTransform(1,0,0,1,0,0);c.globalAlpha=1;c.fillStyle='#000';c.fillRect(0,0,this.canvas.width,this.canvas.height);c.globalAlpha=options.brightness;c.drawImage(this.cache,0,0);c.setTransform(this.dpr,0,0,this.dpr,0,0);
    if(packet.sequence!==this.sequence&&now-this.historyTime>50){this.history.push({packet,time:now});this.history=this.history.filter(t=>now-t.time<180).slice(-3);this.historyTime=now;this.sequence=packet.sequence;}
    let channel=0;for(const item of this.items){const r=item.r;if(item.type==='vu'){needle(c,r,packet.levels[channel][0],item.style,packet.clipped[channel]);channel++;}
      else if(item.type==='fft')this.spectrum(c,r,packet,colors,options.theme);
      else if(item.type==='meter')this.meters(c,r,packet,colors);
      else if(item.type==='ppm')this.ppm(c,r,packet);
      else{const draw=item.type==='wave'?waveform:phaseTrace,color=item.style==='amber'?'#ffbb58':item.style?'#79fca4':colors[1];if(item.style){for(const old of this.history){const age=now-old.time;if(age>15&&age<180){c.globalAlpha=options.brightness*.14*(1-age/180);draw(c,r,old.packet,color,false);}}c.globalAlpha=options.brightness;}draw(c,r,packet,color,!!item.style);if(item.type==='wave')text(c,`${packet.waveformMS.toFixed(1)} ms`,r.x+r.w-3,r.y+r.h-8,8,'#849e8a','right');if(item.style)glass(c,r);}
    }
  }
  spectrum(c,r,p,colors,theme){const q={x:r.x+25,y:r.y+19,w:r.w-30,h:r.h-43};text(c,'20 Hz — 20 kHz',r.x+3,r.y+7,9,'#89988e','left');for(let db=0;db>=-90;db-=30){const y=q.y-db/90*q.h;line(c,q.x,y,q.x+q.w,y,'#26362b',.5);text(c,String(db),q.x-5,y,8,'#738278','right');}for(const [s,x] of [['20',0],['100',.233],['1k',.566],['20k',1]])text(c,s,q.x+x*q.w,q.y+q.h+13,8);const g=gradient(c,q.x,q.y,q.w,q.h,colors,!['mint','thermal','neon','alpine'].includes(theme));const bw=q.w/160;p.spectrum.forEach((db,i)=>{const h=clamp((db+90)/90)*q.h,x=q.x+i*bw;c.fillStyle=g;c.globalAlpha*=.85;c.fillRect(x,q.y+q.h-h,Math.max(.5,bw*.77),h);c.globalAlpha/=.85;const hold=clamp(((p.hold[i]??-90)+90)/90)*q.h;c.fillRect(x,q.y+q.h-hold,Math.max(.5,bw*.77),1);});}
  meters(c,r,p,colors){const top=r.y+27,h=r.h-63,gap=r.w*.18,w=Math.min((r.w-gap)/2,70),left=r.x+(r.w-w*2-gap)/2;for(let ch=0;ch<2;ch++){const x=left+ch*(w+gap);text(c,ch?'R':'L',x+w/2,r.y+9,11);c.fillStyle='#101a13';c.fillRect(x,top,w,h);const fill=clamp((p.levels[ch][0]+60)/60)*h;c.fillStyle=gradient(c,x,top,w,h,colors);c.fillRect(x,top+h-fill,w,fill);const peak=clamp((p.levels[ch][2]+60)/60)*h;line(c,x,top+h-peak,x+w,top+h-peak,colors.at(-1),2);lamp(c,x+w/2,top-8,p.clipped[ch]);text(c,p.levels[ch][0].toFixed(1),x+w/2,top+h+15,Math.max(8,Math.min(13,w*.35)));}text(c,'RMS · dBFS',r.x+r.w/2,r.y+r.h-4,8);}
  ppm(c,r,p){text(c,'PPM · TEST = −18 dBFS',r.x+r.w/2,r.y+5,Math.max(8,Math.min(12,r.w*.035)));const y=r.y+33,h=r.h-73,w=r.w*.39;for(let ch=0;ch<2;ch++){const x=r.x+(ch?r.w-w:0);c.fillStyle=gradient(c,x,y,w,h,['#030604','#101711','#010201']);c.fillRect(x,y,w,h);text(c,ch?'R':'L',x+w*.2,y-12,12);for(let db=-12;db<=12;db+=4){const yy=y+h*(1-(db+12)/24);line(c,x+w*.57,yy,x+w*.94,yy,'#a3ada2');text(c,db===0?'TEST':db>0?`+${db}`:String(db),x+w*.29,yy,9,'#c9d0c6');}const pos=clamp((p.levels[ch][3]+30)/24),yy=y+h*(1-pos);c.save();c.shadowColor='#fff8';c.shadowBlur=4;line(c,x+w*.50,yy+1,x+w*.95,yy,'#fcffed',2);c.restore();text(c,p.levels[ch][3].toFixed(1),x+w/2,y+h+18,12,'#a9b8ab');lamp(c,x+w*.85,y-12,p.clipped[ch]);}text(c,'10 ms · 24 dB / 2.8 s',r.x+r.w/2,r.y+r.h-3,8);}
}
