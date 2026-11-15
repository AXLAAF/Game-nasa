import pathlib,json,subprocess,math,re,wave
R=pathlib.Path('/tmp/mz_trailer');D=29.7
def ff(args):subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error']+list(map(str,args)),check=True)
def dur(p):return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(p)]))
def silence_gap(p):
 with wave.open(str(p),'rb') as w: params=w.getparams();buf=bytearray(w.readframes(w.getnframes()))
 stride=params.nchannels*params.sampwidth;a=round(7.85*params.framerate)*stride;b=round(8*params.framerate)*stride
 # Sample-accurate silence instead of volume's audio-frame granularity.
 buf[a:b]=bytes(b-a)
 with wave.open(str(p),'wb') as w:w.setparams(params);w.writeframes(buf)
def loud_filter(p,target=-18):
 q=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af',f'loudnorm=I={target}:TP=-2:LRA=9:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
 obj=json.JSONDecoder().raw_decode(q.stderr[q.stderr.rfind('{'):])[0]
 return f"loudnorm=I={target}:TP=-2:LRA=9:measured_I={obj['input_i']}:measured_TP={obj['input_tp']}:measured_LRA={obj['input_lra']}:measured_thresh={obj['input_thresh']}:offset={obj['target_offset']}:linear=true"
manifest=json.loads((R/'production_manifest.json').read_text());clips=[];qa=[]
for cue in manifest['voice_cues']:
 label=pathlib.Path(cue['file']).stem
 raw=R/'vo'/(label+'_raw.mp3')
 if label=='vo_07':raw=R/'assets/poll_vo07_new_0.mp3'
 trimmed=R/'vo'/(label+'_trim.wav')
 ff(['-i',raw,'-af','silenceremove=start_periods=1:start_duration=0.01:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_duration=0.01:start_threshold=-50dB,areverse','-ar',48000,'-ac',1,trimmed])
 before=dur(trimmed);window=cue['end']-cue['start'];speed=max(1,before/(window-.025))
 outf=R/'vo'/(label+'.wav')
 ff(['-i',trimmed,'-af',f'rubberband=tempo={speed:.8f},afade=t=in:d=0.004,apad=pad_dur=0.015','-ar',48000,'-ac',1,outf])
 actual=dur(outf)
 assert actual<=window+.002,(label,actual,window)
 qa.append({'clip':label,'raw_trimmed_seconds':before,'tempo_factor':speed,'seconds':actual,'start':cue['start'],'end':cue['start']+actual})
 clips.append((outf,cue['start']))
args=[];filters=[]
for i,(p,start) in enumerate(clips):
 args+=['-i',p];filters.append(f'[{i}:a]adelay={round(start*48000)}S:all=1[a{i}]')
filters.append(''.join(f'[a{i}]' for i in range(len(clips)))+f'amix=inputs={len(clips)}:normalize=0,apad=whole_dur={D},atrim=duration={D},aresample=48000[v]')
ff(args+['-filter_complex',';'.join(filters),'-map','[v]','-ac',2,R/'vo/voice_unleveled.wav'])
ff(['-i',R/'vo/voice_unleveled.wav','-af',loud_filter(R/'vo/voice_unleveled.wav',-16),' -ar'.strip(),48000,'-ac',2,R/'vo/voice_stem.wav'])

# Piecewise rides: full musical accents between phrases, -7 dB under speech.
env='1'
for q in reversed(qa):
 a=max(0,q['start']-.035);b=q['end'];lo=10**(-7/20)
 expr=f'if(lt(t,{a}),1,if(lt(t,{a+.04}),1-(1-{lo})*(t-{a})/.04,if(lt(t,{b}),{lo},if(lt(t,{b+.10}),{lo}+(1-{lo})*(t-{b})/.10,1))))'
 env=f'({env})*({expr})'
env=f'({env})*if(between(t,21,23),1.259,1)*if(between(t,7.85,8),0,1)'
ff(['-i',R/'music/music_original_raw.mp3','-af',loud_filter(R/'music/music_original_raw.mp3',-19),' -ar'.strip(),48000,'-ac',2,R/'music/music_leveled.wav'])
ff(['-i',R/'music/music_leveled.wav','-af',f"volume='{env}':eval=frame,afade=t=out:st=29.2:d=0.5,apad=whole_dur={D},atrim=duration={D}",'-ar',48000,'-ac',2,R/'music/music_stem.wav'])
silence_gap(R/'music/music_stem.wav')

sfx=[('sfx_01_riser',5.5,2.35,-19),('sfx_01_drop',8,1.5,-16),('sfx_02_ignition_launch',15,2,-20),('sfx_03_solar_warning',17,1.5,-25),('sfx_04_reentry_climax',21,2,-17)]
args=[];filters=[]
for i,(label,start,length,target) in enumerate(sfx):
 raw=R/'sfx'/(label+'_raw.mp3');wav=R/'sfx'/(label+'.wav')
 ff(['-i',raw,'-af',loud_filter(raw,target)+f',afade=t=in:d=0.005,afade=t=out:st={length-.08}:d=0.08,apad=whole_dur={length},atrim=duration={length}','-ar',48000,'-ac',2,wav])
 args+=['-i',wav];filters.append(f'[{i}:a]adelay={round(start*48000)}S:all=1[s{i}]')
filters.append(''.join(f'[s{i}]' for i in range(len(sfx)))+f'amix=inputs={len(sfx)}:normalize=0,apad=whole_dur={D},atrim=duration={D}[s]')
ff(args+['-filter_complex',';'.join(filters),'-map','[s]','-ar',48000,'-ac',2,R/'sfx/sfx_stem.wav'])
ff(['-i',R/'vo/voice_stem.wav','-i',R/'music/music_stem.wav','-i',R/'sfx/sfx_stem.wav','-filter_complex',f'[0:a][1:a][2:a]amix=inputs=3:normalize=0,atrim=duration={D}[a]','-map','[a]','-ar',48000,'-ac',2,R/'audio_premaster.wav'])
masterfilter=loud_filter(R/'audio_premaster.wav',-14)
ff(['-i',R/'audio_premaster.wav','-af',masterfilter,'-ar',48000,'-ac',2,R/'audio_trailer_master.wav'])
silence_gap(R/'audio_trailer_master.wav')
(R/'qa/voice_timing.json').write_text(json.dumps(qa,indent=2));(R/'qa/master_filter.txt').write_text(masterfilter)
print(json.dumps(qa,indent=2));print('Audio master ready')
