#!/usr/bin/env python3
"""Run the real ENet smoke with four Godot processes (no external packages)."""
from __future__ import annotations

import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "/Applications/GodotSteam.app/Contents/MacOS/Godot")


class Peer:
    def __init__(self, directory: Path, role: str):
        self.role = role
        self.directory = directory
        self.serial = 0
        self.log_path = directory / f"{role}.log"
        self.log = self.log_path.open("w")
        self.process = subprocess.Popen(
            [GODOT, "--headless", "--path", str(ROOT), "--max-fps", "120",
             "--script", "res://tools/smoke_network.gd", "--", str(directory), role],
            stdout=self.log, stderr=subprocess.STDOUT, cwd=ROOT,
        )

    def wait_response(self, serial: int) -> dict:
        deadline = time.monotonic() + 5
        path = self.directory / f"{self.role}.response.json"
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise AssertionError(f"{self.role} exited: {self.log_path.read_text()}")
            if path.exists():
                response = json.loads(path.read_text())
                if response.get("serial") == serial:
                    return response
            time.sleep(0.01)
        raise AssertionError(f"{self.role}: response {serial} timed out\n{self.log_path.read_text()}")

    def call(self, action="status", **fields) -> dict:
        self.serial += 1
        path = self.directory / f"{self.role}.request.json"
        temporary = path.with_suffix(".tmp")
        temporary.write_text(json.dumps({"serial": self.serial, "action": action, **fields}))
        temporary.replace(path)
        return self.wait_response(self.serial)

    def until(self, predicate, description: str, timeout: float = 5) -> dict:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            response = self.call()
            if predicate(response):
                return response
            time.sleep(0.03)
        raise AssertionError(f"{self.role}: {description}; last response={response}")

    def cleanup(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        self.log.close()


def check(value: bool, message: str):
    if not value:
        raise AssertionError(message)


def smoke(directory: Path, peers: list[Peer]):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    host = Peer(directory, "host")
    peers.append(host)
    host.wait_response(-1)
    check(host.call("host", port=port)["result"] == 0, "ENet server did not start")
    incompatible = Peer(directory, "incompatible")
    peers.append(incompatible)
    incompatible.wait_response(-1)
    check(incompatible.call("join_bad_protocol", port=port)["result"] == 0, "protocol probe could not connect")
    rejected = incompatible.until(lambda s: not s["active"], "incompatible protocol rejection")
    check(any("Версии игры отличаются" in notice for notice in rejected["notices"]), "protocol mismatch lacked explanation")
    check(len(host.call()["members"]) == 1, "incompatible client joined lobby")
    print("ok: incompatible protocol rejected through real hello/reject RPCs", flush=True)
    clients = []
    for number in range(1, 4):
        client = Peer(directory, f"client{number}")
        clients.append(client)
        peers.append(client)
        client.wait_response(-1)
        check(client.call("join", port=port)["result"] == 0, "ENet client did not start")
    roster = host.until(lambda s: len(s["members"]) == 4, "four members in lobby")
    overflow = Peer(directory, "overflow")
    peers.append(overflow)
    overflow.wait_response(-1)
    check(overflow.call("join", port=port)["result"] == 0, "overflow probe could not start")
    rejected = overflow.until(lambda s: not s["active"], "fifth player rejection", timeout=12)
    check(not rejected["members"] and not rejected["running"], "fifth player entered the full lobby")
    check(len(host.call()["members"]) == 4, "overflow changed the four-player lobby")
    print("ok: full four-player lobby rejects a fifth ENet client", flush=True)
    check(not roster["can_start"], "unready players did not block start")
    check(host.call("start")["result"] is False, "start ignored readiness")
    for client in clients:
        client.until(lambda s: len(s["members"]) == 4, "four-player lobby replication")
        client.call("ready")
    host.until(lambda s: s["can_start"], "ready RPCs did not reach host")
    check(host.call("start")["result"] is True, "ready party did not start")
    assignments = {}
    for client in clients:
        state = client.until(lambda s: s["running"] and s["generation"] == 1, "begin RPC")
        assignments[client.role] = state["slot"]
    check(set(assignments.values()) == {1, 2, 3}, "clients did not receive distinct player slots")
    initial = host.call()
    directions = {1: (1, 0), 2: (-1, 0), 3: (0, 1)}
    for client in clients:
        x, y = directions[assignments[client.role]]
        client.call("pump", x=x, y=y)
    host.call("pump")
    time.sleep(0.65)
    for client in clients:
        client.call("pump")
    time.sleep(0.35)
    for client in clients:
        client.call("stop")
    host.call("stop")
    moved = host.call()
    for slot, direction in directions.items():
        before, after = initial["slots"][slot], moved["slots"][slot]
        dx, dy = after["x"] - before["x"], after["y"] - before["y"]
        check(dx * direction[0] + dy * direction[1] > 30, f"client slot {slot} did not move in its own direction")
        check(abs(dx * direction[1] - dy * direction[0]) < 1, f"slot {slot} received another player's input")
    check(moved["slots"][0] == initial["slots"][0], "remote commands moved the host")
    snapshots = [client.call() for client in clients]
    common = set(moved["history"])
    for snapshot in snapshots:
        common &= set(snapshot["history"])
    check(len(common) >= 8, f"not enough common authoritative snapshots: {len(common)}")
    for key in common:
        hashes = {moved["history"][key], *(s["history"][key] for s in snapshots)}
        check(len(hashes) == 1, f"authoritative hash mismatch at generation:tick {key}: {hashes}")
    print(f"ok: four-player lobby, readiness, independent input, {len(common)} identical snapshots", flush=True)

    # Setup positions only; completion is caused by the actual held interact
    # command, followed by snapshots to all three remote processes.
    host.call("fixture_revive")
    started = host.call()["tick"]
    host.call("pump", buttons=2)
    host.until(lambda s: not s["slots"][1]["downed"], "five-second cooperative revive", timeout=8)
    for client in clients:
        revived = client.until(lambda s: not s["slots"][1]["downed"] and s["slots"][1]["health"] == 30,
                               "revive authoritative snapshot")
        check(revived["tick"] >= started + 300, "revive completed before 300 simulation ticks")
    host.call("stop")
    check(host.call()["slots"][1]["health"] == 30, "host revive did not restore 30 HP")
    print("ok: real interact input revives after 300 ticks; all clients receive 30 HP", flush=True)

    host.call("fixture_door")
    host.call("pump", y=-1)
    host.until(lambda s: s["room"] == "center", "movement through north door")
    host.call("pump")
    for client in clients:
        entered = client.until(lambda s: s["room"] == "center", "room transition snapshot")
        check(entered["enemies"] > 0 and entered["waves"] > 0, "transition lost seeded enemies or finite waves")
        check(len([slot for slot in entered["slots"] if slot["occupied"]]) == 4, "transition lost a party member")
    host.call("stop")
    print("ok: real door movement transfers the party and replicates enemies/waves", flush=True)

    host.call("fixture_baron_door")
    host.call("pump", y=-1)
    arrived = host.until(lambda s: s["room"] == "oil_baron", "north door into oil baron room")
    host.call("pump")
    roster = ["ice_agent", "ice_agent", "oil_baron", "soldier", "soldier_dark"]
    for client in clients:
        entered = client.until(lambda s: s["room"] == "oil_baron", "oil baron room snapshot")
        check(sorted(entered["enemy_types"]) == roster, "new room lost boss or a guard")
    host.until(lambda s: "oil_drop" in s["projectile_types"], "oil baron fan after windup")
    for client in clients:
        client.until(lambda s: "oil_drop" in s["projectile_types"], "oil fan replication")
    host.call("stop")
    boss_fight = host.call()
    copies = [client.call() for client in clients]
    common = {key for key in boss_fight["history"] if int(key.split(":")[1]) >= arrived["tick"]}
    for copy in copies:
        common &= set(copy["history"])
    check(len(common) >= 8, "not enough common oil baron snapshots")
    for key in common:
        check(len({boss_fight["history"][key], *(copy["history"][key] for copy in copies)}) == 1,
              f"oil baron authoritative hash mismatch at {key}")
    print("ok: oil baron room, four guards and telegraphed oil fan match on all four peers", flush=True)

    # Queue real movement in the old run before restart, then inject a valid
    # sequence number carrying the old generation after clients received begin.
    for client in clients:
        client.call("pump", x=1)
    time.sleep(0.08)
    for client in clients:
        client.call("stop")
    queued = host.call()
    check(any(b["queued"] > 0 for b in queued["buffers"].values()), "restart test did not create queued inputs")
    host.call("restart")
    baseline = host.call()
    check(baseline["generation"] == 2 and baseline["tick"] == 0, "restart did not establish a new generation")
    for client in clients:
        client.until(lambda s: s["generation"] == 2, "restart begin RPC")
        client.call("stale", epoch=1)
    time.sleep(0.12)
    rejected = host.call()
    check(all(b["received"] == 0 and b["queued"] == 0 for b in rejected["buffers"].values()), "old-generation input entered fresh buffers")
    host.call("pump")
    time.sleep(0.35)
    host.call("stop")
    restarted = host.call()
    check(restarted["slots"] == baseline["slots"], "cached or stale input moved players after restart")
    check(restarted["projectiles"] == 0, "stale input fired after restart")
    print("ok: restart clears queued input and rejects old-generation RPCs", flush=True)

    departed = clients[1]
    departed_slot = assignments[departed.role]
    departed.call("leave")
    remaining = host.until(lambda s: len(s["members"]) == 3, "client disconnect removes member")
    check(not remaining["slots"][departed_slot]["occupied"], "disconnected player's slot stayed occupied")
    for slot in range(4):
        if slot != departed_slot:
            check(remaining["slots"][slot] == restarted["slots"][slot], "disconnect changed another player's slot")
    host.call("pump")
    for client in (clients[0], clients[2]):
        client.until(lambda s: len(s["members"]) == 3 and not s["slots"][departed_slot]["occupied"], "disconnect snapshot")
    print("ok: one disconnect removes exactly its assigned slot on host and clients", flush=True)

    # Abrupt process death, rather than calling a local mock of _lost_host.
    host.process.kill()
    host.process.wait(timeout=2)
    for client in (clients[0], clients[2]):
        lost = client.until(lambda s: not s["active"] and not s["running"] and s["ended_count"] > 0,
                            "host loss cleanup", timeout=12)
        check(not lost["members"] and "slots" not in lost, "host loss kept stale game state")
        check(any("потеряна" in notice for notice in lost["notices"]), "host loss did not explain disconnect")
    print("ok: abrupt host loss ends remaining clients and clears state", flush=True)


def main() -> int:
    peers: list[Peer] = []
    with tempfile.TemporaryDirectory(prefix="lomka-network-") as scratch:
        try:
            smoke(Path(scratch), peers)
            for peer in peers:
                log = peer.log_path.read_text()
                check(not any(marker in log for marker in ("SCRIPT ERROR", "Parse Error", "ERROR:")),
                      f"{peer.role}: engine error\n{log}")
            print("NETWORK SMOKE PASSED: 4 players + 2 rejection probes over real localhost ENet", flush=True)
            return 0
        except (AssertionError, OSError) as error:
            print(f"NETWORK SMOKE FAILED: {error}", flush=True)
            for peer in peers:
                print(f"--- {peer.role} ---\n{peer.log_path.read_text()}", flush=True)
            return 1
        finally:
            for peer in peers:
                peer.cleanup()


if __name__ == "__main__":
    raise SystemExit(main())
