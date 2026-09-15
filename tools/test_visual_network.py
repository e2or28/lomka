#!/usr/bin/env python3
"""Render host plus two real ENet clients and capture animation evidence."""
import json
import socket
import subprocess
import time
from pathlib import Path
from test_network import Peer, ROOT, GODOT, check


class VisiblePeer(Peer):
    def __init__(self, directory, role):
        self.role, self.directory, self.serial = role, directory, 0
        self.log_path = directory / f'{role}.log'
        self.log = self.log_path.open('w')
        self.process = subprocess.Popen([
            GODOT, '--path', str(ROOT), '--max-fps', '60', '--resolution', '1400x880',
            '--script', 'res://tools/preview_network_polish.gd', '--', str(directory), role,
        ], stdout=self.log, stderr=subprocess.STDOUT, cwd=ROOT)

    def wait_response(self, serial):
        if serial != -1:
            return super().wait_response(serial)
        deadline = time.monotonic() + 30
        path = self.directory / f'{self.role}.response.json'
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise AssertionError(self.log_path.read_text())
            if path.exists():
                value = json.loads(path.read_text())
                if value.get('serial') == serial:
                    return value
            time.sleep(0.03)
        raise AssertionError(f'{self.role}: graphical startup timed out')


def main():
    directory = ROOT / '.cache' / 'visual-network'
    directory.mkdir(parents=True, exist_ok=True)
    for path in directory.glob('*.json'):
        path.unlink()
    peers = []
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        host = VisiblePeer(directory, 'host')
        peers.append(host)
        host.wait_response(-1)
        check(host.call('host', port=port)['result'] == 0, 'host failed')
        for name in ['client1', 'client2']:
            client = VisiblePeer(directory, name)
            peers.append(client)
            client.wait_response(-1)
            check(client.call('join', port=port)['result'] == 0, 'join failed')
            client.until(lambda r: len(r['members']) >= 2, 'join')
            client.call('ready')
        host.until(lambda r: len(r['members']) == 3 and r['can_start'], 'readiness')
        check(host.call('start')['result'], 'start failed')
        for peer in peers[1:]:
            peer.until(lambda r: r['running'], 'running')
            peer.call('pump')

        host.call('fixture_polish')
        host.call('pump', buttons=4)
        for peer in peers:
            peer.until(lambda r: r['evidence'].get('harvest_seen'), 'harvest pose', timeout=10)
            peer.call('capture', label='harvest')
        host.until(lambda r: r['tick'] > 90, 'harvest finished', timeout=10)
        host.call('pump', y=-1, aim_y=-1, buttons=1)
        time.sleep(0.4)
        for peer in peers:
            peer.call('capture', label='aim-up')
        host.call('pump')
        host.call('fixture_help')
        host.call('pump', buttons=2)
        for peer in peers:
            peer.until(lambda r: r['evidence'].get('helper_seen'), 'help pose')
            peer.call('capture', label='help')
        host.until(lambda r: r['evidence'].get('revived', 0) > 0, 'revive', timeout=15)
        for peer in peers:
            peer.call('capture', label='rise')
        host.call('pump')
        host.call('fixture_blast')
        host.call('pump', aim_x=1, buttons=1)
        for peer in peers:
            peer.until(lambda r: r['evidence'].get('rider_seen'), 'rappelling')
            peer.call('capture', label='descent')
        host.until(lambda r: r['evidence'].get('explosion', 0) > 0, 'barrel explosion', timeout=12)
        for peer in peers:
            peer.call('capture', label='explosion')
        host.call('crash')
        time.sleep(0.45)
        for peer in peers:
            peer.call('capture', label='crash')
        host.call('pump')
        time.sleep(0.6)
        snapshots = [peer.call() for peer in peers]
        common = set(snapshots[0]['history'])
        for snapshot in snapshots[1:]: common &= set(snapshot['history'])
        check(len(common) >= 8, 'not enough common snapshots')
        for key in common:
            check(len({s['history'][key] for s in snapshots}) == 1, f'snapshot mismatch at {key}')
        for snapshot in snapshots:
            check(snapshot['evidence'].get('explosion', 0) >= 1, 'missing replicated explosion')
            check(snapshot['evidence'].get('revived', 0) >= 1, 'missing replicated revival')
        result = {'common_snapshots': len(common), 'peers': {p.role: s['evidence'] for p, s in zip(peers, snapshots)}}
        (directory / 'result.json').write_text(json.dumps(result, indent=2))
        print('VISUAL NETWORK OK', json.dumps(result), flush=True)
    finally:
        for peer in peers: peer.cleanup()
    for peer in peers:
        check('SCRIPT ERROR' not in peer.log_path.read_text(), f'runtime error in {peer.role}')


if __name__ == '__main__':
    main()
