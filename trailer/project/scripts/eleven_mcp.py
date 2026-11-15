import json, pathlib, sys, urllib.request, urllib.error

ROOT = pathlib.Path('/tmp/mz_trailer')
CREDENTIALS = pathlib.Path.home()/'.claude/.credentials.json'

def call(method, params):
    creds=json.loads(CREDENTIALS.read_text())
    auth=next(v for k,v in creds['mcpOAuth'].items() if k.startswith('elevenlabs|'))
    payload={'jsonrpc':'2.0','id':1,'method':method,'params':params}
    req=urllib.request.Request(auth['serverUrl'],data=json.dumps(payload).encode(),headers={
        'Authorization':'Bearer '+auth['accessToken'],
        'Content-Type':'application/json','Accept':'application/json, text/event-stream',
        'MCP-Protocol-Version':'2025-03-26'})
    try:
        with urllib.request.urlopen(req,timeout=240) as response:
            raw=response.read().decode()
        if raw.startswith('event:') or raw.startswith('data:'):
            messages=[json.loads(line[5:]) for line in raw.splitlines() if line.startswith('data:')]
            return next(m for m in messages if m.get('id')==1)
        return json.loads(raw)
    except urllib.error.HTTPError as e:
        print('HTTP',e.code,e.read().decode()[:2000],file=sys.stderr)
        raise SystemExit(1)

if __name__=='__main__':
    method=sys.argv[1]
    params=json.loads(pathlib.Path(sys.argv[2]).read_text()) if len(sys.argv)>2 else {}
    result=call(method,params)
    if method=='tools/list':
        while result.get('result',{}).get('nextCursor'):
            more=call(method,{'cursor':result['result']['nextCursor']})
            result['result']['tools'].extend(more['result']['tools'])
            result['result']['nextCursor']=more['result'].get('nextCursor')
    label=pathlib.Path(sys.argv[2]).stem if len(sys.argv)>2 else method.replace('/','_')
    out=ROOT/('eleven_'+label+'.json')
    out.write_text(json.dumps(result,indent=2))
    print(out)
    if method=='tools/list':
        for t in result.get('result',{}).get('tools',[]): print(t['name'],t.get('description','')[:150])
    else:
        r=result.get('result',result)
        if 'structuredContent' in r: r=r['structuredContent']
        elif r.get('content') and r['content'][0].get('text'):
            try: r=json.loads(r['content'][0]['text'])
            except ValueError: pass
        for i,g in enumerate(r.get('generations',[]) or []):
            if g.get('status')=='completed' and g.get('content_url'):
                dest=ROOT/'assets'/(label+'_'+str(i)+'.mp3')
                with urllib.request.urlopen(g['content_url'],timeout=120) as response: dest.write_bytes(response.read())
                print('Downloaded',dest,'duration',g.get('duration_secs'))
        if r.get('generations'):
            print(json.dumps({k:v for k,v in r.items() if k in ['all_completed','has_failures','error','error_message','poll_after_seconds']}))
        else: print(json.dumps(r)[:5500])
