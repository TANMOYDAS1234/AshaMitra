const fs=require('fs'),path=require('path');
const ROOT=path.resolve(__dirname,'..');
const ENV=path.join(ROOT,'ashamitra','backend','.env');
const OUT=path.join(__dirname,'samples');
const LAST=path.join(OUT,'splash_frame_last.png');
function key(){const t=fs.readFileSync(ENV,'utf8');let p=null,a=null;for(const l of t.split(/\r?\n/)){const m=l.match(/^\s*(GEMINI_API_KEY(?:_\d+)?)\s*=\s*(.+)\s*$/);if(!m)continue;const v=m[2].replace(/^["']|["']$/g,'').trim();if(!v)continue;if(m[1]==='GEMINI_API_KEY')p=v;a??=v;}return p||a;}
function img(d){const ps=d?.candidates?.[0]?.content?.parts||[];for(const p of ps){const x=p.inlineData?.data||p.inline_data?.data;if(x)return x;}return null;}
function dims(b){return b.length>24&&b[1]===0x50?`${b.readUInt32BE(16)}x${b.readUInt32BE(20)}`:'?';}
const FIRST='Using the SAME mother, SAME newborn, SAME cream-and-lavender saree, SAME plum background, SAME lighting and SAME vertical framing as this image, show a slightly EARLIER moment: her head lifted a little, gazing down tenderly at the sleeping baby with eyes gently open and a soft smile forming. Keep identical photographic style, colours, composition and aspect ratio. Only the head tilt and gaze change.';
(async()=>{const K=key();
const parts=[{inlineData:{mimeType:'image/png',data:fs.readFileSync(LAST).toString('base64')}},{text:FIRST}];
let err='';
for(const m of ['gemini-2.5-flash-image']){
  try{const r=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${K}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({contents:[{parts}],generationConfig:{responseModalities:['IMAGE']}})});
  if(!r.ok){err=`${m}:${r.status} ${(await r.text()).slice(0,140)}`;continue;}
  const b=img(await r.json());if(!b){err=`${m}:noimg`;continue;}
  const buf=Buffer.from(b,'base64');fs.writeFileSync(path.join(OUT,'splash_frame_first.png'),buf);
  console.log(`first ${m} ${dims(buf)} ${(buf.length/1333).toFixed(0)}KB`);return;}catch(e){err=e.message;}
}
console.error('FAIL '+err);process.exit(2);})();
