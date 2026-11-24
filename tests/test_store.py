#!/usr/bin/env python3
"""python3 tests/test_store.py -- aequalyn-store's records and catalog, without a network."""
import json, os, pathlib, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
STORE = pathlib.Path(os.environ.get("STORE_UNDER_TEST", ROOT / "bin/aequalyn-store"))
fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print("FAIL", what)


with tempfile.TemporaryDirectory() as tmp:
    tmp = pathlib.Path(tmp)
    state = tmp / "state/aequalyn-store"
    state.mkdir(parents=True)
    env = dict(os.environ, HOME=str(tmp), XDG_CONFIG_HOME=str(tmp / "config"), XDG_DATA_HOME=str(tmp / "data"),
               XDG_STATE_HOME=str(tmp / "state"), PATH=str(tmp / "bin") + ":" + os.environ["PATH"])
    (tmp / "bin").mkdir()
    # a pacman that has one package, and that waits for input on "-" as the real one does
    (tmp / "bin/pacman").write_text('#!/bin/sh\nfor a; do [ "$a" = - ] && sleep 30; [ "$a" = here ] && exit 0; done\nexit 1\n')
    (tmp / "bin/pacman").chmod(0o755)

    def store(*args):
        try:
            return subprocess.run([sys.executable, str(STORE), *args], env=env, capture_output=True, text=True, timeout=10)
        except subprocess.TimeoutExpired:
            return subprocess.CompletedProcess(args, 99, "", "it hangs")

    C1, C2 = "1" * 40, "2" * 40
    R = "https://github.com/someone/"
    (state / "installed.json").write_text(json.dumps({
        "app:here": {"kind": "app", "id": "here", "source": R + "a", "commit": C1, "packages": ["here"], "market": True},
        "app:gone": {"kind": "app", "id": "gone", "source": R + "b", "commit": C1, "packages": ["gone"], "market": True},
        "app:bare": {"kind": "app", "id": "bare", "source": R + "c", "commit": C1},
        "app:odd": {"kind": "app", "id": "odd", "packages": ["-"]},
        "later:x": {"kind": "later", "id": "x"},
        "theme:t": {"kind": "theme", "id": "t", "source": R + "t", "commit": C1, "market": True}}))
    (state / "market.json").write_text(json.dumps({"version": 1, "items": [
        {"kind": "app", "id": "here", "repo": R + "a", "commit": C1}, {"kind": "app", "id": "gone", "repo": R + "b", "commit": C1},
        {"kind": "app", "id": "bare", "repo": R + "c", "commit": C1}, {"kind": "theme", "id": "t", "repo": R + "t", "commit": C2},
        {"kind": "look", "id": "t", "repo": R + "l", "commit": C1}, {"kind": "theme", "id": "other", "repo": R + "o", "commit": C1}]}))

    def rows(text):
        try:
            return json.loads(text)
        except ValueError:
            return []

    r = store("list", "--json")
    ok(r.returncode == 0, "the list is made whatever is in it: " + r.stderr[-120:])
    present = {f"{i['kind']}:{i['id']}": i["present"] for i in rows(r.stdout)}
    ok(present == {"app:here": True, "app:gone": False, "app:bare": False, "app:odd": False, "later:x": False, "theme:t": False},
       f"what is here: {present}")
    ok(store("list").returncode == 0, "the plain list")
    r = store("market", "--json")
    states = {f"{i['kind']}:{i['id']}": i["state"] for i in rows(r.stdout)}
    ok(states == {"app:here": "installed", "app:gone": "not installed", "app:bare": "not installed", "theme:t": "update available",
                  "look:t": "not installed", "theme:other": "not installed"}, f"the catalog's states: {states} {r.stderr[-60:]}")
    for args in (("update", "app", "here"), ("remove", "app", "here"), ("install-market", "theme:nope"), ("list", "nope")):
        r = store(*args)
        ok(r.returncode != 0 and "Traceback" not in r.stderr, "refused, not crashed: " + " ".join(args))

print(f"store: {fails} failures")
sys.exit(1 if fails else 0)
