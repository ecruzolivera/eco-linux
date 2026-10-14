#!/usr/bin/env python3
"""Provision reviewed plugins without replacing existing unfamiliar installations."""
import json
import subprocess
from pathlib import Path

PLUGINS = [
    ('ez-corp.git-status', 'ezcorp-org/herdr-git-status', 'f144c8dac2860e344b6b379d2bcfee229dcf10ad'),
    ('mikebronner.recent-spaces', 'mike-bronner/herdr-plugin-recent-spaces', '88d6f0590ba5e44c7f0ae3167462aa2b27178f38'),
]


def installed():
    response = json.loads(subprocess.check_output(['herdr', 'plugin', 'list', '--json'], text=True, timeout=120))
    if 'error' in response or response.get('result', {}).get('type') != 'plugin_list':
        raise RuntimeError('Unable to read Herdr plugin list')
    return {plugin['plugin_id']: plugin for plugin in response['result']['plugins']}


def bootstrap():
    plugins = installed()
    local = Path.home() / '.config/herdr/plugins/local/eco-ws-number'
    existing = plugins.get('eco.ws-number')
    if existing:
        if Path(existing['plugin_root']).resolve() != local.resolve():
            raise RuntimeError('Local workspace plugin is linked elsewhere; preserved for manual review')
    else:
        subprocess.run(['herdr', 'plugin', 'link', str(local), '--enabled'], check=True, timeout=600)
        if 'eco.ws-number' not in installed():
            raise RuntimeError('Local plugin did not register')
    for plugin_id, repository, revision in PLUGINS:
        existing = plugins.get(plugin_id)
        if existing:
            source = existing['source']
            if (source.get('kind') != 'github' or source.get('resolved_commit') != revision
                    or f'{source.get("owner")}/{source.get("repo")}' != repository):
                raise RuntimeError(f'{plugin_id}: unreviewed existing plugin preserved; inspect/unlink it manually')
            checkout = subprocess.check_output(['git', '-C', existing['plugin_root'], 'rev-parse', 'HEAD'], text=True, timeout=120).strip()
            if checkout != revision:
                raise RuntimeError(f'{plugin_id}: checkout differs from recorded revision; preserved for review')
            dirty = subprocess.check_output(['git', '-C', existing['plugin_root'], 'status', '--porcelain', '--untracked-files=no'], text=True, timeout=120)
            if dirty:
                raise RuntimeError(f'{plugin_id}: local modifications preserved; review before bootstrap')
        else:
            subprocess.run(['herdr', 'plugin', 'install', repository, '--ref', revision], check=True, timeout=600)
            registered = installed().get(plugin_id)
            if not registered or registered['source'].get('resolved_commit') != revision:
                raise RuntimeError(f'{plugin_id}: installation was declined or did not register the expected revision')
        print(f'PASS: reviewed Herdr plugin {plugin_id} at {revision}')


if __name__ == '__main__':
    bootstrap()
