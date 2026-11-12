"""Canonical committed runtime identity independent of checkout line endings."""
import hashlib
import json
import subprocess

PREFIXES=('game/','platform/','assets/','addons/','scenes/','LICENSES/')
FILES=('project.godot','export_presets.cfg','LICENSE','NOTICE')

def runtime_git_identity(root):
    entries=subprocess.check_output(['git','ls-tree','-rz','HEAD'],cwd=root).decode().split('\0')
    blobs={}
    for entry in entries:
        if not entry:
            continue
        header,path=entry.split('\t',1)
        if path.startswith(PREFIXES) or path in FILES:
            blobs[path]=header.split()[2]
    return hashlib.sha256(json.dumps(blobs,sort_keys=True).encode()).hexdigest()
