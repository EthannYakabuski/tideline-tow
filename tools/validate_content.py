"""Check the shipping content contract with no third-party Python dependencies."""
from pathlib import Path
import json
import re
import struct

ROOT = Path(__file__).resolve().parents[1]

def png_size(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'Not PNG: ' + str(path)
    return struct.unpack('>II', data[16:24])

def main():
    for folder in ('game','platform','docs','review','public','marketing'):
        for path in (ROOT/folder).rglob('*'):
            if path.is_file() and path.suffix in ('.gd','.json','.md','.html','.txt'):
                text = path.read_text(encoding='utf-8-sig')
                assert not any((ord(c)<32 and c not in '\t\r\n') or c=='\ufffd' for c in text), 'Invalid text character: '+str(path)
    cfg = json.loads((ROOT/'platform/config.json').read_text(encoding='utf-8-sig'))
    store = json.loads((ROOT/'marketing/store.json').read_text(encoding='utf-8-sig'))
    assert 0 < len(store['short_description']) <= 80
    assert 0 < len(store['long_description']) <= 4000
    assert cfg['admob']['test_mode'] is True
    assert cfg['admob']['app_id'] == 'ca-app-pub-3940256099942544~3347511713'
    assert cfg['play_games']['enabled'] is False and not cfg['play_games']['game_id']
    assert len(cfg['play_games']['achievements']) == 20
    assert len(cfg['play_games']['leaderboards']) == 3
    assert all(not value for value in cfg['play_games']['achievements'].values())
    assert all(not value for value in cfg['play_games']['leaderboards'].values())
    assert png_size(ROOT/'assets/brand/app-icon.png') == (512,512)
    for group in ('achievements','leaderboards'):
        for key in cfg['play_games'][group]:
            width,height = png_size(ROOT/f'assets/brand/{group}/{key}.png')
            assert width == height and width >= 128, f'Invalid {group} icon: {key}'
            assert png_size(ROOT/f'marketing/{group}/{key}.png') == (512,512)
    feature = ROOT/'marketing/feature-graphic.png'
    assert png_size(feature) == (1024,500)
    for profile,size in {'phone':(1080,1920),'tablet7':(800,1280),'tablet10':(1200,1920)}.items():
        files = list((ROOT/f'marketing/screenshots/{profile}').glob('*.png'))
        assert len(files) >= 6, f'Need six real captures: {profile}'
        for path in files:
            assert png_size(path) == size, f'Unexpected capture size: {path}'
    for name in ('LICENSE','NOTICE','LICENSES/admob-MIT.txt','LICENSES/GodotPlayGameServices-MIT.txt','LICENSES/GodotEngine-MIT.txt','LICENSES/NotoSansCJK-OFL.txt','LICENSES/kenney-watercraft.txt','LICENSES/kenney-pirate.txt','LICENSES/kenney-industrial.txt','LICENSES/kenney-ui-pack.txt'):
        assert (ROOT/name).is_file(), 'Missing notice: ' + name
    for html in ('review/index.html','public/index.html'):
        assert (ROOT/html).is_file(), 'Missing page: ' + html
    source = (ROOT/'game/content.gd').read_text(encoding='utf-8-sig')
    for key in cfg['play_games']['achievements']:
        assert '"'+key+'"' in source, 'Unmapped achievement: '+key
    assert not list(ROOT.glob('*.keystore')) and not list(ROOT.glob('*.jks'))
    print('CONTENT_PASS: 20 achievement icons, 3 boards, branding, 18+ sized real captures, service placeholders and notices')

if __name__ == '__main__':
    main()
