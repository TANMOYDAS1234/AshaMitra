const fs=require('fs'),path=require('path');
const ROOT=path.resolve(__dirname,'..');
const ENV=path.join(ROOT,'ashamitra','backend','.env');
const OUT=path.join(__dirname,'samples');
function key(){const t=fs.readFileSync(ENV,'utf8');let p=null,a=null;for(const l of t.split(/\r?\n/)){const m=l.match(/^\s*(GEMINI_API_KEY(?:_\d+)?)\s*=\s*(.+)\s*$/);if(!m)continue;const v=m[2].replace(/^["']|["']$/g,'').trim();if(!v)continue;if(m[1]==='GEMINI_API_KEY')p=v;a??=v;}return p||a;}
function img(d){const ps=d?.candidates?.[0]?.content?.parts||[];for(const p of ps){const x=p.inlineData?.data||p.inline_data?.data;if(x)return x;}return null;}
function dims(buf){ // PNG IHDR
  if(buf.length>24&&buf[1]===0x50) return `${buf.readUInt32BE(16)}x${buf.readUInt32BE(20)}`;
  return '?';
}
async function gen(K,parts){
  // try with 9:16 imageConfig, then fall back to plain
  const cfgs=[{responseModalities:['IMAGE'],imageConfig:{aspectRatio:'9:16'}},{responseModalities:['IMAGE']}];
  let err='';
  for(const cfg of cfgs){
    for(const m of ['gemini-2.5-flash-image','gemini-2.5-flash-image-preview']){
      try{const r=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${K}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({contents:[{parts}],generationConfig:cfg})});
      if(!r.ok){err=`${m} cfg=${JSON.stringify(cfg.imageConfig||{})}: ${r.status} ${(await r.text()).slice(0,120)}`;continue;}
      const b=img(await r.json());if(!b){err=`${m}: noimg`;continue;}
      return {b64:b,model:m,ar:cfg.imageConfig?'9:16':'default'};}catch(e){err=e.message;}
    }
  }
  throw new Error(err);
}
const LAST='A tender, beautiful photorealistic vertical portrait: a young Indian mother in a soft cream-and-lavender saree cradling her sleeping newborn wrapped in white muslin against her chest, resting her cheek gently on the baby\'s head, eyes closed, serene loving smile. Warm soft diffused light, calm dignified hopeful mood. Smooth plum-tinted studio background with soft vignette, darker toward the top for overlay text. Full-frame vertical 9:16 portrait, subject in the lower two-thirds. No text, no logo, no watermark.';
(async()=>{const K=key();fs.mkdirSync(OUT,{recursive:true});
// last frame
let out=await gen(K,[{text:LAST}]);
const lastBuf=Buffer.from(out.b64,'base64');
fs.writeFileSync(path.join(OUT,'splash_frame_last.png'),lastBuf);
console.log(`last  ${out.model} ${out.ar} ${dims(lastBuf)} ${(lastBuf.length/1333).toFixed(0)}KB`);
// first frame conditioned on last
const FIRST='Using the SAME mother, SAME newborn, SAME cream-and-lavender saree, SAME plum background, SAME lighting and SAME vertical 9:16 framing as the reference, show a slightly EARLIER moment: her head lifted a little, gazing down tenderly at the sleeping baby with eyes gently open and a soft smile forming. Keep identical style, colours, composition and 9:16 aspect. Only the head tilt and gaze change.';
out=await gen(K,[{inlineData:{mimeType:'image/png',data:out.b64}},{text:FIRST}]);
const firstBuf=Buffer.from(out.b64,'base64');
fs.writeFileSync(path.join(OUT,'splash_frame_first.png'),firstBuf);
console.log(`first ${out.model} ${out.ar} ${dims(firstBuf)} ${(firstBuf.length/1333).toFixed(0)}KB`);
})().catch(e=>{console.error('FAIL '+e.message);process.exit(2);});
