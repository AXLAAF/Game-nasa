import json, pathlib, sys, urllib.request, time
from eleven_mcp import call

ROOT=pathlib.Path('/tmp/mz_trailer')
FLOW='BAEAHiPFoIgGWuwnglk6'
VOICE='20BLHNU68Kmgsrc8Ixqj'

def tool(name,args,label):
    raw=call('tools/call',{'name':name,'arguments':args})
    (ROOT/('api_'+label+'.json')).write_text(json.dumps(raw,indent=2))
    r=raw.get('result',raw)
    if 'structuredContent' in r: r=r['structuredContent']
    elif r.get('content') and r['content'][0].get('text'):
        try:r=json.loads(r['content'][0]['text'])
        except ValueError:pass
    if r.get('error') or r.get('isError'): raise RuntimeError(str(r)[:2000])
    return r

def transcribe(path):
    p=pathlib.Path(path); label=p.stem
    asset_file=ROOT/(label+'_reference.json')
    if asset_file.exists(): asset=json.loads(asset_file.read_text())
    else:
        upload=tool('creative_create_asset_upload',{'name':p.name,'mime_type':'audio/wav','file_size':p.stat().st_size},label+'_upload')
        request=urllib.request.Request(upload['upload_url'],data=p.read_bytes(),method='PUT',headers={'Content-Type':'audio/wav'})
        with urllib.request.urlopen(request,timeout=120) as response: print('Uploaded',response.status,flush=True)
        asset=tool('creative_finalize_asset_upload',{'asset_id':upload['asset_id'],'flow_id':FLOW},label+'_asset')
        asset_file.write_text(json.dumps(asset))
    node=asset.get('node_id')
    if not node: raise RuntimeError('Missing reference node: '+str(asset))
    result=tool('creative_generate_in_flow',{'flow_id':FLOW,'node_type':'speech-to-text','model_id':'eleven_scribe_v1','prompt':'Transcribe the English speech verbatim.','connect_from':[node],'generations_count':1},label+'_asr_start')
    print(json.dumps(result)[:1800],flush=True)
    (ROOT/(label+'_asr_job.json')).write_text(json.dumps(result))

def poll_asr(label):
    job=json.loads((ROOT/(label+'_asr_job.json')).read_text())
    ids=job.get('session_ids') or [job['session_id']]
    r=tool('creative_get_flow_run_status',{'flow_id':FLOW,'session_ids':ids},label+'_asr_status')
    print(json.dumps(r)[:5500],flush=True)

def start_audio():
    statefile=ROOT/'audio_jobs.json'
    jobs=json.loads(statefile.read_text()) if statefile.exists() else []
    if jobs:
        print('Jobs already prepared; not regenerating.');return
    manifest=json.loads((ROOT/'production_manifest.json').read_text())
    for cue in manifest['voice_cues']:
        if cue['file']=='vo_07.mp3':continue
        label=pathlib.Path(cue['file']).stem
        fast='[very fast delivery]' if label in ['vo_02','vo_03','vo_04'] else '[brisk delivery]'
        if label=='vo_08':fast='[warmly]'
        args={'flow_id':FLOW,'node_type':'tts','model_id':'eleven_v4','voice_id':VOICE,'prompt':'[confident] '+fast+' '+cue['text'],'label':label}
        jobs.append({'label':label,'folder':'vo','args':args})
    prompt=('Original instrumental cinematic spacecraft game trailer. Exactly 120 BPM, rigid quarter-note pulse every 0.5 seconds, 4/4 time, D minor. '
    'No vocals, no choir, no speech. Analog synthesizer bass, restrained low strings, monumental brass and powerful orchestral percussion. '
    'One coherent thirty-second cue with precisely timed sections: 0-8s sparse ominous deep pulse and growing string tension, no main drums yet; '
    'at 8s a huge heroic D bass impact and brass entry; 12-21s urgent propulsive ostinato and tightly quantized drums; '
    '21-23s maximum intensity with brass and percussion, strongest climax; at 23s sudden drop to restrained low pulse for two seconds; '
    'at 25s broad heroic resolving chord, last attack at 28s with a beautiful decaying tail and full silence by 30s. '
    'Start immediately on beat, finish musically, professional trailer mix with space for a deep narrator. No melody quotations.')
    jobs.append({'label':'music_original','folder':'music','args':{'flow_id':FLOW,'node_type':'music','model_id':'eleven_music_v2_5','prompt':prompt,'model_parameters':{'duration_seconds':30,'lyrics_type':'instrumental','instrumental':True},'label':'Original trailer music — 120 BPM D minor'}})
    sfx=[('sfx_01_riser',2.35,'Cinematic tension riser, dry metallic air and rising low orchestral texture, grows continuously for 2.35 seconds, stops before any impact. No voice. No melody.'),
    ('sfx_01_drop',1.5,'Single huge cinematic sub bass impact, tuned to D, immediate attack at the very start, deep controlled resonant tail, subtle brass body, no additional impacts, no voice.'),
    ('sfx_02_ignition_launch',2,'A tiny ignition lock click immediately followed by a powerful close rocket engine igniting, deep roaring combustion, sustained ascending thrust, clean movie sound effect, no voices.'),
    ('sfx_03_solar_warning',1.5,'Spacecraft solar storm warning: two restrained low electronic warning pulses with dry electromagnetic crackle. Serious realistic cockpit alarm, no voice, no high piercing tone.'),
    ('sfx_04_reentry_climax',2,'Intense spacecraft atmospheric reentry: compressed turbulent plasma roar, rising low pressure, climax with one deep cinematic impact one second into the sound, then decays. No voices.')]
    for label,duration,prompt in sfx:
        jobs.append({'label':label,'folder':'sfx','args':{'flow_id':FLOW,'node_type':'sfx','model_id':'eleven_text_to_sound_v2','prompt':prompt,'model_parameters':{'duration_seconds':duration,'prompt_influence':.7,'loop':False},'label':label}})
    statefile.write_text(json.dumps(jobs,indent=2))
    for job in jobs:
        result=tool('creative_add_flow_node',job['args'],job['label']+'_node')
        job['node_id']=result.get('node_id') or result.get('node_ids',[None])[0]
        if not job['node_id']: raise RuntimeError(str(result))
        statefile.write_text(json.dumps(jobs,indent=2));print('Prepared',job['label'],flush=True)
    estimate=tool('creative_run_flow_nodes',{'flow_id':FLOW,'node_ids':[j['node_id'] for j in jobs],'generations_count':1,'estimate_only':True},'all_audio_estimate')
    print('Estimate:',json.dumps(estimate)[:1800],flush=True)
    result=tool('creative_run_flow_nodes',{'flow_id':FLOW,'node_ids':[j['node_id'] for j in jobs],'generations_count':1},'all_audio_start')
    for item in result.get('results',[]):
        for job in jobs:
            if item['node_id']==job['node_id']:job['session_id']=item.get('session_id');job['start_success']=item.get('success')
    statefile.write_text(json.dumps(jobs,indent=2));print('Started:',result.get('summary'),flush=True)

def poll_audio():
    statefile=ROOT/'audio_jobs.json';jobs=json.loads(statefile.read_text())
    for job in jobs:
        if job.get('downloaded') or not job.get('session_id'):continue
        r=tool('creative_get_flow_run_status',{'flow_id':FLOW,'session_ids':[job['session_id']]},job['label']+'_status')
        for g in r.get('generations',[]) or []:
            if g.get('status')=='completed' and g.get('content_url'):
                p=ROOT/job['folder']/(job['label']+'_raw.mp3')
                with urllib.request.urlopen(g['content_url'],timeout=120) as response:p.write_bytes(response.read())
                job['downloaded']=str(p);job['duration']=g.get('duration_secs');print('Downloaded',job['label'],job['duration'],flush=True)
            elif g.get('status')=='failed':job['error']=g.get('error_message');print('FAILED',job['label'],job['error'],flush=True)
            else: print('Pending',job['label'],g.get('status'),flush=True)
        statefile.write_text(json.dumps(jobs,indent=2))

if __name__=='__main__':
    if sys.argv[1]=='transcribe': transcribe(sys.argv[2])
    elif sys.argv[1]=='poll-asr': poll_asr(sys.argv[2])
    elif sys.argv[1]=='start-audio': start_audio()
    elif sys.argv[1]=='poll-audio': poll_audio()
