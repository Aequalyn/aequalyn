#!/usr/bin/env python3
"""python3 tests/test_browser_theme.py -- the browsers take the theme's colour: Firefox's profiles, and the policy"""
import json, os, pathlib, subprocess, sys, tempfile

BIN = pathlib.Path(__file__).resolve().parent.parent / "bin/aequalyn-browser-theme"
PAL = ["#101018", "#181824", "#202030", "#303040", "#e8e8f0", "#8888a0", "#f2c53d"]
fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print("FAIL", what)


def home(t, enabled=True):
    h = pathlib.Path(t) / "h"
    (h / ".config/aequalyn").mkdir(parents=True); (h / ".config/quickshell").mkdir()
    (h / ".config/aequalyn/settings.json").write_text(json.dumps({"appearance": {"themeBrowser": enabled}}))
    (h / ".mozilla/firefox/abc.default").mkdir(parents=True)
    (h / ".mozilla/firefox/profiles.ini").write_text("[Profile0]\nName=x\nIsRelative=1\nPath=abc.default\n[Profile1]\nPath=gone\n")
    (h / ".zen/z z").mkdir(parents=True)
    (h / ".zen/profiles.ini").write_text("[Profile0]\r\nPath=z z\r\n")
    b = pathlib.Path(t) / "bin"; b.mkdir()
    # no browser of the policy kind here, and a gate that says no
    for k, v in {"find": "exit 0", "aequalyn-watchdog": "echo denied; exit 126", "ps": "echo", "aequalyn-themes":
                 "echo '" + json.dumps([{"id": "gold", "palette": dict(zip(["bgBase", "bgSurface", "bgHover", "bgBorder", "textPrimary", "textMuted", "accentPrimary"], PAL))}]) + "'"}.items():
        (b / k).write_text("#!/bin/sh\n" + v + "\n"); (b / k).chmod(0o755)
    for k in ("jq", "cat", "sed", "grep", "mkdir", "mv", "rm", "sort", "head", "readlink", "id", "tail", "tr", "cut", "bash", "env", "dirname"):
        if not (b / k).exists():
            (b / k).symlink_to("/usr/bin/" + k)
    return h, b


def run(h, b, *args):
    r = subprocess.run(["/usr/bin/bash", str(BIN), *args], capture_output=True, text=True, timeout=30,
                       env={"HOME": str(h), "PATH": str(b), "LANG": "C.UTF-8"})
    ok("command not found" not in r.stderr and "unbound" not in r.stderr, "it runs: " + r.stderr[-200:])
    return r


with tempfile.TemporaryDirectory() as t:
    h, b = home(t)
    f, z = h / ".mozilla/firefox/abc.default", h / ".zen/z z"
    (f / "chrome").mkdir(); (f / "chrome/userChrome.css").write_text("/* mine */\n#x { color: red }\n"); (f / "user.js").write_text('user_pref("a", 1);\n')
    for _ in range(2):
        run(h, b, "sync", "--color", PAL[0], "--palette", ",".join(PAL))
    css = (f / "chrome/aequalyn.css").read_text()
    ok(all(c in css for c in PAL), "a profile has the theme's colours")
    uc = (f / "chrome/userChrome.css").read_text()
    ok(uc.startswith('@import "aequalyn.css";') and uc.count("aequalyn.css") == 1 and "#x { color: red }" in uc, "read before your own style, once")
    ok((f / "user.js").read_text().count("legacyUserProfileCustomizations") == 1 and 'user_pref("a", 1);' in (f / "user.js").read_text(), "and the browser reads it")
    ok((z / "chrome/aequalyn.css").read_text() == css and (z / "user.js").exists(), "Zen's too, a path with a space and Windows line ends")
    ok(not (h / ".mozilla/firefox/gone").exists(), "no profile is made")
    new = ["#ffffff"] + PAL[1:]
    run(h, b, "sync", "--color", new[0], "--palette", ",".join(new))
    ok("--toolbox-bgcolor: #ffffff" in (f / "chrome/aequalyn.css").read_text(), "another theme, other colours")
    run(h, b, "sync", "--color", "#000000", "--palette", "#000000,red;},#x")
    ok("red" not in (f / "chrome/aequalyn.css").read_text(), "nothing but colours is written")
    (h / ".config/quickshell/theme.conf").write_text("theme:gold")
    run(h, b, "on")
    ok("--toolbox-bgcolor: #101018" in (f / "chrome/aequalyn.css").read_text(), "turned on, it finds the theme's colours itself")
    run(h, b, "off")
    ok(not (f / "chrome/aequalyn.css").exists() and (f / "chrome/userChrome.css").read_text() == "/* mine */\n#x { color: red }\n" and (f / "user.js").read_text() == 'user_pref("a", 1);\n', "off leaves what was yours, exactly")
    ok(not (z / "chrome/userChrome.css").exists() and not (z / "user.js").exists(), "and nothing of ours")
with tempfile.TemporaryDirectory() as t:
    h, b = home(t, enabled=False)
    run(h, b, "sync", "--color", PAL[0], "--palette", ",".join(PAL))
    ok(not (h / ".mozilla/firefox/abc.default/chrome").exists(), "off in Settings is off")
# which of the open browsers is told: told apart by name
src = BIN.read_text()
for args, cmd, want in (("/usr/lib/chromium/chromium --type=x", "chromium", True), ("/opt/google/chrome/chrome", "google-chrome-stable", True),
                        ("/opt/microsoft/msedge/msedge", "microsoft-edge-stable", True), ("/opt/brave-bin/brave --a", "brave", True),
                        ("/opt/vivaldi/vivaldi-bin", "vivaldi-stable", True), ("vim chromium.txt", "chromium", False), ("/usr/lib/firefox/firefox", "chromium", False)):
    a = src.index("        name=${cmd%-stable}"); e = src.index("|| continue", src.index("grep -qE", a))
    r = subprocess.run(["bash", "-c", f'cmd={cmd}; running="{args}"; {src[a:e]}'])
    ok((r.returncode == 0) == want, f"{args} is {'' if want else 'not '}{cmd}")
print("browser theme:", fails, "failures")
sys.exit(1 if fails else 0)
