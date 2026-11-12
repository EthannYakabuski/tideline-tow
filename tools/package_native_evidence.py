"""Validate and package existing isolated emulator observations, without device IO."""
from pathlib import Path
import hashlib, json, shutil

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'build/native'
TARGET=ROOT/'docs/evidence/native'
RUNTIME='7b001133ef71903209ec713c1dd3e4218334d329'
APKS={'acceptance':'b5a08c40bafa33bb37d2c2184931f0cf4a32096dc6cee1675afc947e75914fbc',
      'ordinary':'4233f7a76b2ca6016c8e2714de0c116936d2745901bcbab42729943b69d73026'}

def main():
    checks=[]
    def check(value,label):
        assert value,label
        checks.append(label)
    files=['v2-no-reward-after-dismissal.json','v2-interstitial-open.json',
           'v2-interstitial-after-dismissal.json','v2-reward-earned-open.json',
           'v2-reward-after-dismissal.json','v2-reward-cold.json',
           'v2-reward-after-resume.json','ordinary-controls-profile.json','ordinary-cold-profile.json']
    records={name:json.loads((SOURCE/name).read_bytes()) for name in files}
    for name,item in records.items():
        if name.startswith('v2-'):check(item.get('acceptance_only') is True,name+' isolated acceptance profile')
    def events(record):return [item.get('event') for item in record['events']]
    no=records[files[0]]
    check(no['state']['status']=='failed' and no['state']['hull']==0,'no-earned closure retains failure')
    check(not no['state']['continued'] and not no['fullscreen'],'no-earned closure grants no continuation')
    check('native_fullscreen_closed' in events(no) and 'real_reward_earned' not in events(no),'no earned callback in no-reward journey')
    opened=records[files[1]];closed=records[files[2]]
    check(opened['fullscreen'] and opened['profile']['stats']['rounds']==6,'real sixth-result interstitial open')
    check(not closed['fullscreen'] and 'native_fullscreen_closed' in events(closed),'real interstitial dismissal')
    check(opened['state']==closed['state'] and opened['profile']==closed['profile'],'interstitial dismissal preserves settlement')
    check(closed['profile']['coins']==333 and closed['profile']['xp']==270,'sixth-result payout remains committed')
    earned=records[files[3]];dismissed=records[files[4]];cold=records[files[5]];won=records[files[6]]
    check(earned['fullscreen'] and earned['pause']=='ad_return','earned callback keeps fullscreen pause')
    check(events(earned).count('real_reward_earned')==1,'one real earned callback recorded')
    check(earned['state']['continued'] and earned['state']['hull']==2,'earned recovery repairs exactly once')
    check(earned['state']['remaining']==45,'earned recovery grants 45 seconds')
    check(not dismissed['fullscreen'] and dismissed['pause']=='paused','dismissal requires neutral resume')
    check('native_fullscreen_closed' in events(dismissed),'reward dismissal callback observed')
    check(dismissed['state']==earned['state'],'reward dismissal does not advance game')
    # Restoring deliberately discards transient per-tick events, avoiding replay.
    persistent=lambda state:{key:value for key,value in state.items() if key!='events'}
    check(persistent(cold['state'])==persistent(dismissed['state']) and cold['pause']=='paused','cold restart retains all persistent earned state')
    check(cold['state']['events']==[],'cold restart clears transient fail event')
    check(won['state']['run_id']==earned['state']['run_id'],'resumed victory belongs to same run')
    check(won['state']['status']=='won' and won['state']['delivered']==3 and won['state']['score']==561,'resumed real rescue victory')
    check(won['state']['continued'] and won['state']['hull']==2,'continued flag survives completed rescue')
    check(won['profile']['coins']==162 and won['profile']['xp']==100 and won['profile']['stats']['rounds']==1,'resumed victory pays once')
    check(won['profile']['settled'].count(won['state']['run_id'])==1,'single durable settlement identity')
    ordinary=[]
    for name in files[-2:]:
        envelope=records[name]
        check(hashlib.sha256(envelope['body'].encode()).hexdigest()==envelope['sha256'],name+' checksum')
        ordinary.append(json.loads(envelope['body']))
    check(ordinary[0]['active']==ordinary[1]['active'],'ordinary touch-driven run survives cold restart')
    active=ordinary[0]['active']
    check(active['delivered']==1 and active['score']==100 and active['hull']==3,'ordinary real touch input delivered a boat')
    check(active['status']=='running' and active['elapsed']>0,'ordinary parked rescue remains resumable')
    receipt=json.loads((ROOT/'docs/build-evidence.json').read_bytes())
    for kind,key in [('acceptance','tideline-tow-acceptance.apk'),('ordinary','tideline-tow-test.apk')]:
        check(receipt['artifacts']['build/android/'+key]['sha256']==APKS[kind],kind+' APK receipt identity')
    check(receipt['source_commit_at_receipt']==RUNTIME,'tested runtime receipt identity')
    TARGET.mkdir(parents=True,exist_ok=True)
    images=['v2-repaired-hud.png','v2-interstitial-close-ready.png','v2-reward-cold-paused.png','ordinary-helm-delivery.png','ordinary-cold-home.png']
    packaged=[]
    for name in files+images:
        source=SOURCE/name;dest=TARGET/name
        shutil.copyfile(source,dest)
        digest=hashlib.sha256(source.read_bytes()).hexdigest()
        check(hashlib.sha256(dest.read_bytes()).hexdigest()==digest,name+' copied byte-for-byte')
        packaged.append({'file':name,'bytes':source.stat().st_size,'sha256':digest})
    manifest={'runtime_commit':RUNTIME,'apk_sha256':APKS,'environment':'Pixel 3a API30 x86 emulator, GLES3; not physical-device testing',
      'provenance':'Existing task-created isolated profiles. JSON scenario names reflect reused probes; use the documented journey and file names. Interstitial history includes two seeded prior rounds, three actual wins and one failed watch. Ordinary profiles use real ADB touch input without the autopilot. PNGs are original unmodified captures. No raw network/ad logs or owner progress are included.',
      'assertions_passed':len(checks),'checks':checks,'files':packaged}
    (TARGET/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(f'NATIVE_EVIDENCE_PASS: {len(checks)} assertions; {len(packaged)} unchanged evidence files')

if __name__=='__main__':main()
