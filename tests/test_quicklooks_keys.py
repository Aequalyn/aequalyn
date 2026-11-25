#!/usr/bin/env python3
"""python3 tests/test_quicklooks_keys.py -- the newer Quick looks keys on existing installs"""
import os, pathlib, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIG = ROOT / "migrations/20261125-3.sh"
B = 'hl.bind(M .. " + CTRL + B", hl.dsp.exec_cmd("qs ipc call quickLooks bar")) -- Quick looks\n'
G = 'hl.bind(M .. " + CTRL + G", hl.dsp.exec_cmd("qs ipc call quickLooks login")) -- Quick looks\n'
C = 'hl.bind(M .. " + CTRL + C", hl.dsp.exec_cmd("qs ipc call quickLooks cursor")) -- Quick looks\n'
W = 'hl.bind(M .. " + CTRL + W", hl.dsp.exec_cmd("qs ipc call quickLooks showcase")) -- Quick looks\n'
M = 'hl.bind(M .. " + CTRL + M", hl.dsp.exec_cmd("qs ipc call quickLooks all")) -- Quick looks\n'
fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print("FAIL", what)


def run(keys, extra=None):
    with tempfile.TemporaryDirectory() as tmp:
        hypr = pathlib.Path(tmp) / "homes/u/.config/hypr"
        hypr.mkdir(parents=True)
        (pathlib.Path(tmp) / "homes/empty").mkdir()
        (hypr / "keybinds.lua").write_text(keys)
        if extra:
            (hypr / "user.lua").write_text(extra)
        for _ in range(2):
            r = subprocess.run(["bash", str(MIG)], capture_output=True, text=True,
                               env=dict(os.environ, AEQUALYN_MIGRATION_HOMES=str(pathlib.Path(tmp) / "homes")))
            ok(r.returncode == 0, "it runs: " + r.stderr)
        ok(len(list(hypr.iterdir())) == (2 if extra else 1), "nothing left behind")
        return (hypr / "keybinds.lua").read_text()


ok(run("a\n" + B + G + "b\n") == "a\n" + B + G + C + W + M + "b\n", "all are added after the others, once")
ok(run("a\n" + B + "\n\n" + G + "\nb\n") == "a\n" + B + "\n\n" + G + C + W + M + "\nb\n", "with gaps between them too")
ok(run("a\nb\n") == "a\nb\n", "nothing without the Quick looks keys")
ok(run("-- " + B) == "-- " + B, "nor when they are commented out")
ok(run(B, 'hl.bind("SUPER + CTRL + C", x)\n') == B + W + M, "a taken key is kept")
ok(run(B, 'hl.bind("SUPER + CTRL + c", x)\n') == B + W + M, "however it is written")
ok(run(B, 'hl.bind("SUPER + CTRL + CODE", x)\n') == B + C + W + M, "another key is not it")
shipped = (ROOT / "config/hypr/keybinds.lua").read_text()
ok(run(shipped) == shipped, "the shipped file has them")
ok(shipped.count("+ CTRL + C\"") == 1 and shipped.count("+ CTRL + W\"") == 1 and shipped.count("+ CTRL + M\"") == 1, "each key once")
print("quick looks keys:", fails, "failures")
sys.exit(1 if fails else 0)
