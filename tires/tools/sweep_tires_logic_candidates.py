#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path('tires/godot')
OUT = Path('tires/shared/logic_port_candidates_v1.json')

RUNTIME_TOKENS = [
    'get_node', 'add_child', 'queue_free', 'RayCast', 'Physics', 'RigidBody', 'Area3D',
    'global_transform', 'apply_central_force', 'apply_force', 'apply_impulse', 'Node3D',
    'Node ', 'extends Node', 'extends Node3D', 'extends CharacterBody', 'Input.',
]

MIXED_TOKENS = [
    'Time.get_unix_time_from_system',
    'Engine.get_process_frames',
]

def classify(path: Path):
    txt = path.read_text(errors='ignore')
    lines = txt.splitlines()
    extends = ''
    for ln in lines[:8]:
        s = ln.strip()
        if s.startswith('extends '):
            extends = s
            break

    runtime_hits = [t for t in RUNTIME_TOKENS if t in txt]
    mixed_hits = [t for t in MIXED_TOKENS if t in txt]

    if 'extends "res://tires/' in txt and len(lines) <= 2:
        return 'alias_wrapper', ['compat alias wrapper']

    if runtime_hits:
        if extends.startswith('extends RefCounted'):
            return 'mixed_extractable', ['runtime tokens in otherwise pure class'] + runtime_hits[:3]
        return 'runtime_bound', runtime_hits[:4]

    if extends.startswith('extends RefCounted') or 'class_name' in txt:
        if mixed_hits:
            return 'mixed_extractable', mixed_hits[:2]
        return 'pure_logic_candidate', ['refcounted/no runtime token']

    return 'mixed_extractable', ['default conservative classification']


def wave_for(category):
    if category == 'pure_logic_candidate':
        return 1
    if category == 'mixed_extractable':
        return 2
    return None


def main():
    entries = []
    for p in sorted(ROOT.glob('**/*.gd')):
        cat, reasons = classify(p)
        entries.append({
            'file': str(p),
            'category': cat,
            'wave': wave_for(cat),
            'reasons': reasons,
        })

    out = {
        'version': 'logic_port_candidates_v1',
        'scope': 'tires/godot',
        'summary': {
            'total_files': len(entries),
            'pure_logic_candidate': sum(1 for e in entries if e['category'] == 'pure_logic_candidate'),
            'mixed_extractable': sum(1 for e in entries if e['category'] == 'mixed_extractable'),
            'runtime_bound': sum(1 for e in entries if e['category'] == 'runtime_bound'),
            'alias_wrapper': sum(1 for e in entries if e['category'] == 'alias_wrapper'),
        },
        'entries': entries,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, indent=2) + '\n')
    print(f'WROTE {OUT}')
    print(json.dumps(out['summary'], indent=2))


if __name__ == '__main__':
    main()
