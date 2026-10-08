#!/usr/bin/env python3
"""Build an offline Assembly evidence watch page from reviewed local recordings.
Input JSON is an evidence manifest, never a fixture generator. No network calls.
"""
from pathlib import Path
import argparse, base64, hashlib, html, json
p=argparse.ArgumentParser();p.add_argument('manifest',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
m=json.loads(a.manifest.read_text());esc=lambda s:html.escape(str(s),quote=True)
required=['title','sourceRevision','scope','limitations','recordings']
for key in required:
 if not m.get(key):raise SystemExit('Missing evidence field: '+key)
clips=[];files=[]
concept=m.get('conceptURL','https://github.com/amiller/apple-attest-p2p/tree/main/design/mac-journey')
if not concept.startswith('https://'):raise SystemExit('Concept URL must use HTTPS')
for i,r in enumerate(m['recordings']):
 for key in ['path','title','evidenceLabel','description','assertions','limitations']:
  if not r.get(key):raise SystemExit(f'Recording {i}: missing {key}')
 path=(a.manifest.parent/r['path']).resolve()
 if path.suffix.lower()!='.mp4':raise SystemExit('Expected reviewed MP4 recording')
 data=path.read_bytes();digest=hashlib.sha256(data).hexdigest()
 if r.get('sha256')!=digest:raise SystemExit('Recording hash does not match reviewed manifest: '+str(path))
 files.append({'file':path.name,'sha256':digest,'bytes':len(data)})
 checks=''.join('<li>'+esc(x)+'</li>' for x in r['assertions'])
 limits=''.join('<li>'+esc(x)+'</li>' for x in r['limitations'])
 clips.append(f'''<section class="recording"><div class="meta"><span>{i+1:02d} / {esc(r['evidenceLabel'])}</span><span>RECORDED EVIDENCE</span></div><h2>{esc(r['title'])}</h2><p>{esc(r['description'])}</p><video controls playsinline preload="metadata" aria-label="{esc(r['title'])}"><source src="data:video/mp4;base64,{base64.b64encode(data).decode()}" type="video/mp4">Use the offline HTML in a browser that supports MP4 video.</video><div class="columns"><div><h3>Observed checks</h3><ul>{checks}</ul></div><div><h3>Limits of this recording</h3><ul>{limits}</ul></div></div></section>''')
screens=[]
for shot in m.get('screenshots',[]):
 path=(a.manifest.parent/shot['path']).resolve();data=path.read_bytes();digest=hashlib.sha256(data).hexdigest()
 if shot.get('sha256')!=digest or path.suffix.lower()!='.png':raise SystemExit('Unreviewed screenshot')
 files.append({'file':path.name,'sha256':digest,'bytes':len(data)})
 screens.append('<figure><img style="max-width:100%;height:auto" alt="'+esc(shot['caption'])+'" src="data:image/png;base64,'+base64.b64encode(data).decode()+'"><figcaption>'+esc(shot['caption'])+'</figcaption></figure>')
screenSection=('<section class="recording"><div class="meta">Actual native controls / captioned screenshots</div>'+''.join(screens)+'</section>') if screens else ''
links=''.join(f'<li><a href="{esc(x["url"])}">{esc(x["label"])}</a></li>' for x in m.get('sources',[]))
limits=''.join('<li>'+esc(x)+'</li>' for x in m['limitations'])
page='''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>__TITLE__</title><style>*{box-sizing:border-box}body{margin:0;background:#f6f5f0;color:#151515;font:16px/1.5 -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif}main{max-width:1120px;padding:40px 28px 60px;margin:auto}.eyebrow,.meta{font:11px/1.6 ui-monospace,monospace;text-transform:uppercase;letter-spacing:1px}.eyebrow{border-left:5px solid #df321d;padding-left:12px}h1{font-size:clamp(42px,7vw,80px);line-height:.98;letter-spacing:-3px;max-width:900px;margin:22px 0}h2{font-size:32px;line-height:1.1;letter-spacing:-1px;margin:18px 0}h3{font-size:14px}p{max-width:800px;color:#50535c}.recording{border-top:1px solid #151515;margin-top:38px;padding-top:14px}.meta{display:flex;justify-content:space-between;gap:20px}.meta span:first-child{color:#214dba}video{display:block;width:100%;max-height:730px;background:#171719;border-radius:8px;margin:24px 0}figure{margin:24px 0}figcaption{font-size:13px;color:#50535c;max-width:850px}.columns{display:grid;grid-template-columns:1fr 1fr;gap:30px}.columns>div{border-top:1px solid #cccdc7}li{font-size:13px;color:#50535c;margin:8px 0}ul{padding-left:18px}a{color:#bb2615;text-underline-offset:3px}.limits{background:#eaeceF;padding:18px 24px;margin-top:30px}footer{margin-top:35px;border-top:1px solid #cccdc7;font-size:12px;padding-top:18px;color:#50535c}code{overflow-wrap:anywhere;font-size:11px}@media(max-width:650px){main{padding:26px 16px}.columns{grid-template-columns:1fr;gap:12px}.meta{display:block}.meta span{display:block}h1{letter-spacing:-2px}h2{font-size:27px}}</style></head><body><main><header><div class="eyebrow">ATTESTNODE / ASSEMBLY / ACCEPTANCE RECORDINGS</div><h1>__TITLE__</h1><p>__SCOPE__</p><nav aria-label="Evidence or design"><strong>Recorded app</strong> · <a href="__CONCEPT__">17-screen design prototype ↗</a></nav><p>Press Play to watch. Each player supports pause, seeking and fullscreen. The HTML and ZIP downloads include the recordings for offline use.</p></header>__CLIPS____SCREENS__<section class="limits"><h3>Still outside this evidence</h3><ul>__LIMITS__</ul></section><footer><h3>Evidence and source</h3><ul>__LINKS__</ul><p>Source revision: <code>__REV__</code></p><p>Research testnet. No monetary value or permanent unique-device identity. Anyone holding this unlisted report link can view it. Embedded recordings play offline; source links require internet access.</p></footer></main></body></html>'''
for key,value in {'TITLE':esc(m['title']),'SCOPE':esc(m['scope']),'CLIPS':''.join(clips),'SCREENS':screenSection,'LIMITS':limits,'LINKS':links,'REV':esc(m['sourceRevision']),'CONCEPT':esc(concept)}.items():page=page.replace('__'+key+'__',value)
if len(page.encode())>9_800_000:raise SystemExit('Offline HTML exceeds 9.8 MB publication budget; compress reviewed clips first')
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(page)
a.out.with_suffix('.evidence.json').write_text(json.dumps({'sourceRevision':m['sourceRevision'],'recordings':files,'htmlSHA256':hashlib.sha256(page.encode()).hexdigest(),'manifest':m},indent=2)+'\n')
print(a.out)
