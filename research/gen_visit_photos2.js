const fs=require('fs'),path=require('path');
const ROOT=path.resolve(__dirname,'..');
const ENV=path.join(ROOT,'ashamitra','backend','.env');
const IMG=path.join(ROOT,'ashamitra','assets','images','visits');
function key(){const t=fs.readFileSync(ENV,'utf8');let p=null,a=null;for(const l of t.split(/\r?\n/)){const m=l.match(/^\s*(GEMINI_API_KEY(?:_\d+)?)\s*=\s*(.+)\s*$/);if(!m)continue;const v=m[2].replace(/^["']|["']$/g,'').trim();if(!v)continue;if(m[1]==='GEMINI_API_KEY')p=v;a??=v;}return p||a;}
function img(d){const ps=d?.candidates?.[0]?.content?.parts||[];for(const p of ps){const x=p.inlineData?.data||p.inline_data?.data;if(x)return x;}return null;}
function dims(b){return b.length>24&&b[1]===0x50?`${b.readUInt32BE(16)}x${b.readUInt32BE(20)}`:'?';}
const S=' Warm photorealistic documentary photograph, soft natural light, shallow depth of field, dignified hopeful caring mood. Soft plum-and-cream tones matching a maternal-health app (purple #791C87 / magenta #BD3773 accents). Wide landscape 16:9, subject slightly right so lower-left stays calm for a caption. No text, no logo, no watermark.';
const ITEMS=[
 ['hbnc.png','A peaceful sleeping Indian newborn baby swaddled in soft white muslin with a tiny cap, close-up, calm face.'+S],
 ['hbyc.png','A happy healthy Indian toddler about one to two years old, big joyful smile, chubby cheeks, sitting up.'+S],
 ['vaccine.png','A reassuring positive moment: a smiling Indian mother holding her healthy baby, a small vaccine vial resting on a clean cloth nearby, gentle and non-scary.'+S],
];
async function gen(K,prompt){let err='';
 for(const cfg of [{responseModalities:['IMAGE'],imageConfig:{aspectRatio:'16:9'}},{responseModalities:['IMAGE']}])
 for(const m of ['gemini-2.5-flash-image']){
   try{const r=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${K}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({contents:[{parts:[{text:prompt}]}],generationConfig:cfg})});
   if(!r.ok){err=`${r.status} ${(await r.text()).slice(0,110)}`;continue;}
   const b=img(await r.json());if(!b){err='noimg';continue;}return b;}catch(e){err=e.message;}}
 throw new Error(err);}
(async()=>{const K=key();fs.mkdirSync(IMG,{recursive:true});
for(const [f,p] of ITEMS){try{const b=await gen(K,p);const buf=Buffer.from(b,'base64');fs.writeFileSync(path.join(IMG,f),buf);console.log(`OK ${f} ${dims(buf)} ${(buf.length/1333).toFixed(0)}KB`);}catch(e){console.error(`FAIL ${f}: ${e.message}`);}}
console.log('DONE');})();
