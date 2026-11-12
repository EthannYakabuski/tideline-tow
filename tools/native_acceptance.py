"""Operate only Tideline Tow on a specified disposable Android test emulator."""
import argparse, json, os, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PACKAGE='com.ethannyakabuski.tidelinetow'
ADB=Path(os.environ['LOCALAPPDATA'])/'Android/Sdk/platform-tools/adb.exe'

def main():
    p=argparse.ArgumentParser()
    p.add_argument('action',choices=['start','read','ordinary','capture','pull','tap','back'])
    p.add_argument('--serial',default='emulator-5554')
    p.add_argument('--profile',default='native-contract-final')
    p.add_argument('--scenario',choices=['contract','rewarded','interstitial','cold'],default='contract')
    p.add_argument('--name',default='capture')
    p.add_argument('--x',type=int);p.add_argument('--y',type=int)
    a=p.parse_args()
    if not a.serial.startswith('emulator-'):
        raise SystemExit('This helper is restricted to a disposable emulator.')
    for value in [a.profile,a.name]:
        if not all(c.isalnum() or c in '-_' for c in value):raise SystemExit('Unsafe evidence name')
    target=ROOT/'build/native';target.mkdir(parents=True,exist_ok=True)
    def adb(*args,input=None):
        return subprocess.run([str(ADB),'-s',a.serial,*args],input=input,capture_output=True,check=True).stdout
    if a.action=='start':
        adb('shell','am','force-stop',PACKAGE)
        cfg=json.dumps({'enabled':True,'profile':a.profile,'scenario':a.scenario}).encode()
        adb('shell','run-as',PACKAGE,'sh','-c',"'cat > files/qa_probe.json'",input=cfg)
        print(adb('shell','am','start','-n',PACKAGE+'/com.godot.game.GodotApp').decode())
    elif a.action=='read':
        data=adb('exec-out','run-as',PACKAGE,'cat',f'files/qa/{a.profile}-evidence.json')
        parsed=json.loads(data);(target/f'{a.profile}-evidence.json').write_bytes(data)
        print(json.dumps({k:parsed.get(k) for k in ['scenario','phase','screen','pause','fullscreen']}))
        state=parsed.get('state',{});print(json.dumps({k:state.get(k) for k in ['status','elapsed','delivered','continued','run_id','hull','score']}))
        events=parsed.get('events',[])
        print(json.dumps({'event_count':len(events),'last_events':[{k:v for k,v in item.items() if k!='profile'} for item in events[-8:]]},ensure_ascii=False))
        profile=parsed.get('profile',{})
        print(json.dumps({'coins':profile.get('coins'),'xp':profile.get('xp'),'stats':profile.get('stats')}))
    elif a.action=='ordinary':
        data=adb('exec-out','run-as',PACKAGE,'cat','files/profile_v1.json')
        outer=json.loads(data);profile=json.loads(outer['body'])
        (target/f'{a.name}.json').write_bytes(data)
        state=profile.get('active',{})
        print(json.dumps({'coins':profile.get('coins'),'xp':profile.get('xp'),'login':profile.get('login'),'active':{k:state.get(k) for k in ['run_id','status','elapsed','position','hull','tow','delivered','score']}}))
    elif a.action=='capture':
        path=target/f'{a.name}.png';path.write_bytes(adb('exec-out','screencap','-p'));print(path)
    elif a.action=='pull':
        for name in ['tow','result']:
            try:
                data=adb('exec-out','run-as',PACKAGE,'cat',f'files/qa/{a.profile}-{name}.png')
                path=target/f'{a.profile}-{name}.png';path.write_bytes(data);print(path)
            except subprocess.CalledProcessError:print('Capture not present:',name)
    elif a.action=='tap':
        assert a.x is not None and a.y is not None
        adb('shell','input','tap',str(a.x),str(a.y))
    elif a.action=='back':adb('shell','input','keyevent','4')

if __name__=='__main__':main()
