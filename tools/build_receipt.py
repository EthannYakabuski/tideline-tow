"""Bind built files to their precise runtime source tree; no credentials or saves."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile
from source_identity import runtime_git_identity

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()

def main():
    artifacts = {}
    for rel in ['build/android/tideline-tow-debug.aab',
                'build/android/tideline-tow-test.apk',
                'build/android/tideline-tow-acceptance.apk',
                'build/site/play/index.pck', 'build/site/play/index.wasm']:
        path = ROOT / rel
        if not path.is_file():
            raise SystemExit('Missing required built artifact: ' + rel)
        artifacts[rel] = {'bytes': path.stat().st_size, 'sha256': digest(path)}
        if path.suffix in ('.apk', '.aab'):
            with zipfile.ZipFile(path) as bundle:
                names = bundle.namelist()
                found = [n for n in names if n.endswith('/platform/config.json')]
                assert len(found) == 1, 'Missing packaged service config'
                config = json.loads(bundle.read(found[0]))
                assert config['admob']['test_mode'] is True
                assert config['play_games']['enabled'] is False
                assert not config['play_games']['game_id']
                assert any(n.endswith('/LICENSES/admob-MIT.txt') for n in names)
                assert not any('/tests/' in n or '/marketing/' in n or n.endswith(('.keystore', '.jks')) for n in names)
                artifacts[rel]['packaged_test_configuration'] = 'PASS'
    tracked = subprocess.check_output(['git','ls-files','-z'], cwd=ROOT).decode().split('\0')
    runtime = {p:digest(ROOT/p) for p in tracked if p and
               (p.startswith(('game/','platform/','assets/','addons/','scenes/','LICENSES/'))
                or p in ('project.godot','export_presets.cfg','LICENSE','NOTICE'))}
    commit = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    receipt = {'game':'Tideline Tow','source_commit_at_receipt':commit,
               'runtime_git_blobs_sha256':runtime_git_identity(ROOT),
               'runtime_tree_sha256': hashlib.sha256(json.dumps(runtime,sort_keys=True).encode()).hexdigest(),
               'engine':'Godot 4.5.1.stable.official.f62fdbde1',
               'package':'com.ethannyakabuski.tidelinetow','version':'1.0.0 (1)',
               'artifacts':artifacts,'runtime_source_files_sha256':runtime,
               'physical_device_verified':False,'production_services_verified':False}
    (ROOT/'docs/build-evidence.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'source_commit':commit,'artifacts':artifacts},indent=2))

if __name__ == '__main__':
    main()
