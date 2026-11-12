"""Check intended tracked/unignored publication files without printing secrets."""
from pathlib import Path
import re, subprocess

ROOT=Path(__file__).resolve().parents[1]
PATTERNS={
 'credential-like token':re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|AIza[A-Za-z0-9_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'),
 'private Windows user path':re.compile(r'[A-Z]:[/\\]Users[/\\](?!Public[/\\])[^/\\\s]+'),
}

def main():
    raw=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=ROOT)
    files=sorted(set(p for p in raw.decode().split('\0') if p));problems=[]
    for name in files:
        path=ROOT/name
        if not path.is_file():continue
        if path.suffix.lower() in ('.keystore','.jks','.p12','.env') or '.private.' in name:
            problems.append((name,'private file extension'))
        if path.suffix.lower() not in ('.gd','.cfg','.json','.md','.html','.txt','.py','.yml','.yaml','.godot','.tscn') and path.name not in ('LICENSE','NOTICE','HANDOFF.txt'):
            continue
        try:text=path.read_text(encoding='utf-8-sig')
        except UnicodeDecodeError:continue
        for label,pattern in PATTERNS.items():
            if pattern.search(text):problems.append((name,label))
        for ad in re.findall(r'ca-app-pub-\d{16}[~/]\d+',text):
            if not ad.startswith('ca-app-pub-3940256099942544'):problems.append((name,'non-sample AdMob identifier'))
    if problems:
        for name,label in problems:print('REVIEW:',name,label)
        raise SystemExit('Public audit needs review; matching contents were not printed.')
    print(f'PUBLIC_AUDIT_PASS: {len(files)} intended files; no detected secret tokens, private paths, signing files or non-sample ad IDs')

if __name__=='__main__':main()
