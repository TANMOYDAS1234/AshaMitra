const fs=require('fs'),path=require('path');
const ROOT=path.resolve(__dirname,'..');
const ENV=path.join(ROOT,'ashamitra','backend','.env');
const OUT=path.join(__dirname,'samples');
const LAST=path.join(ROOT,'ashamitra','assets','images','splash_mother.png');
function key(){const t=fs.readFileSync(ENV,'utf8');let p=null,a=null;for(const l of t.split(/\r?\n/)){const m=l.match(/^\s*(GEMINI_API_KEY(?:_\d+)?)\s*=\s*(.+)\s*$/);if(!m)continue;const v=m[2].replace(/^["']|["']$/g,'').trim();if(!v)continue;if(m[1]==='GEMINI_API_KEY')p=v;a??=v;}return p||a;}
const PROMPT='Using the SAME mother and newborn, SAME cream-and-lavender saree, SAME plum background, SAME soft lighting and SAME framing as the reference image, generate a slightly EARLIER moment: the mother is holding her sleeping newborn a touch further from her face, her head lifted a little, gazing down tenderly at the baby with eyes gently open and a soft gentle smile just forming. Keep identical photographic style, colours, composition and 1:1 aspect. Only the head tilt and gaze change.';
const ATT=[['gemini-2.5-flash-image',{responseModalities:['IMAGE']}],['gemini-2.5-flash-image-preview',{responseModalities:['IMAGE']}]];
function img(d){const ps=d?.candidates?.[0]?.content?.parts||[];for(const p of ps){const x=p.inlineData?.data||p.inline_data?.data;if(x)return x;}return null;}
(async()=>{const K=key();fs.mkdirSync(OUT,{recursive:true});
const parts=[{inlineData:{mimeType:'image/png',data:fs.readFileSync(LAST).toString('base64')}},{text:PROMPT}];
let err='';for(const[m,c]of ATT){try{const r=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${K}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({contents:[{parts}],generationConfig:c})});if(!r.ok){err=`${m}:${r.status}`;continue;}const b=img(await r.json());if(!b){err=`${m}:noimg`;continue;}fs.writeFileSync(path.join(OUT,'splash_frame_first.png'),Buffer.from(b,'base64'));fs.copyFileSync(LAST,path.join(OUT,'splash_frame_last.png'));console.log(`OK frames -> research/samples/ (${m})`);return;}catch(e){err=e.message;}}
console.error('FAIL '+err);process.exit(2);})();
