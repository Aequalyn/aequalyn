#!/usr/bin/env python3
"""python3 tests/test_hyprbars.py -- the titlebar plugin is made for the Hyprland that runs"""
import os, pathlib, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOL = ROOT / "bin/aequalyn-hyprbars"
fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print("FAIL", what)


with tempfile.TemporaryDirectory() as tmp:
    tmp = pathlib.Path(tmp)
    fake, home, src = tmp / "bin", tmp / "home", tmp / "src"
    for d in (fake, home, src):
        d.mkdir()
    (src / "main.cpp").write_text("one")
    (src / "globals.hpp").write_text("one")
    header, run_abi, log, plug = tmp / "version.h", tmp / "running", tmp / "log", tmp / "loaded"

    def headers(hg, patch="0"):
        header.write_text("".join('#define %s "%s"\n' % x for x in (
            ("GIT_COMMIT_HASH", "abc"), ("AQUAMARINE_VERSION", "0.16.0"), ("HYPRUTILS_VERSION", "0.14.4"),
            ("HYPRGRAPHICS_VERSION", "%s.%s" % (hg, patch)), ("HYPRCURSOR_VERSION", "0.1.14"), ("HYPRLANG_VERSION", "0.6.8"))))

    def abi(hg):
        return "abc_aq_0.16_hu_0.14_hg_%s_hc_0.1_hlg_0.6" % hg

    def running(hg):
        run_abi.write_text(abi(hg))
        plug.unlink(missing_ok=True)
        log.write_text("")

    def tool(name, text):
        (fake / name).write_text("#!/bin/bash\n" + text)
        (fake / name).chmod(0o755)

    # a compiler whose output says which headers it saw, and a Hyprland that takes only its own
    tool("g++", f'echo g++ >> {log}; [[ -e {tmp}/broken ]] && exit 1\n'
                f'while [[ $1 != -o ]]; do shift; done; grep GRAPHICS {header} > "$2"')
    tool("pkg-config", "echo -I/x")
    tool("hyprctl", f'''case "$1 $2" in
        "version -j") printf '{{"abiHash":"%s"}}' "$(cat {run_abi})" ;;
        "plugin list") [[ -e {plug} ]] && echo "Plugin hyprbars by Vaxry:" ;;
        "plugin load") echo load >> {log}; v=$(grep -o '"[0-9]*\\.[0-9]*' "$3" | tr -d '"')
                       [[ -n "$v" && "$(cat {run_abi})" == *_hg_"$v"_* ]] && touch {plug} ;;
        eval*) echo eval >> {log} ;;
    esac; true''')
    tool("qs", f"echo resync >> {log}; echo ok")
    tool("notify-send", f"echo told >> {log}")
    tool("aequalyn-shell-restart", f"echo restart >> {log}")
    tool("sleep", "true")
    env = {"HOME": str(home), "PATH": f"{fake}:/usr/bin", "AEQUALYN_HYPR_HEADERS": str(header), "AEQUALYN_HYPRBARS_SRC": str(src)}
    so = home / ".local/lib/aequalyn/hyprbars.so"
    stamp = so.with_suffix(".abi")

    def run(*a, **e):
        return subprocess.run(["bash", str(TOOL), *a], env=dict(env, **e), capture_output=True, text=True, timeout=30)

    def did():
        return log.read_text().split()

    headers("0.6", "3")
    ok(run("abi").stdout.strip() == abi("0.6"), "the headers' ABI, without patch numbers: " + run("abi").stdout)
    running("0.6")
    ok(run("load").returncode == 0 and plug.exists(), "nothing there: it is built and loaded")
    ok(did() == ["told", "g++", "load", "eval", "resync"], "in that order: %s" % did())
    ok(stamp.read_text().strip() == abi("0.6"), "and noted")
    running("0.6")
    ok(run("load").returncode == 0 and did() == ["load", "eval", "resync"], "the next login just loads it: %s" % did())
    log.write_text("")
    ok(run("load").returncode == 0 and did() == ["eval", "resync"], "already loaded: only set up: %s" % did())
    # Arch's 25 November: same Hyprland, newer hyprgraphics
    headers("0.7")
    running("0.6")
    ok(run("load").returncode == 0 and "g++" not in did(), "updated, not logged in again: the one that fits stays")
    running("0.7")
    ok(run("load").returncode == 0 and plug.exists() and "g++" in did(), "after it, built anew: %s" % did())
    ok(stamp.read_text().strip() == abi("0.7"), "noted anew")
    # a copy from before they were noted, of another Hyprland (what every system has now)
    stamp.unlink()
    so.write_text('#define HYPRGRAPHICS_VERSION "0.6.0"\n')
    running("0.7")
    ok(run("load").returncode == 0 and plug.exists() and "g++" in did(), "an old copy that does not fit is replaced")
    stamp.unlink()
    running("0.7")
    ok(run("load").returncode == 0 and did() == ["load", "eval", "resync"], "one that fits is used: %s" % did())
    # the ISO's own build
    so.unlink()
    (src / "built").mkdir()
    (src / "built/hyprbars.so").write_text('#define HYPRGRAPHICS_VERSION "0.7.0"\n')
    (src / "built/hyprbars.abi").write_text(abi("0.7") + "\n")
    running("0.7")
    ok(run("load").returncode == 0 and "g++" not in did() and stamp.exists(), "the ISO's own build is taken: %s" % did())
    # an install with a newer Hyprland than the ISO, and one the headers are not of
    headers("0.8")
    running("0.8")
    ok(run("load").returncode == 0 and "g++" in did(), "an install with a newer one builds its own")
    running("0.9")
    ok(run("load").returncode == 1 and "g++" not in did(), "never built from other headers")
    # a build that fails is not tried at every login
    headers("0.9")
    (tmp / "broken").touch()
    running("0.9")
    ok(run("load").returncode == 1 and did().count("g++") == 1 and did().count("told") == 2, "a failure is told: %s" % did())
    ok(stamp.read_text().strip() == abi("0.8") and not list(so.parent.glob("*.so.*")), "and leaves nothing behind")
    running("0.9")
    ok(run("load").returncode == 1 and "g++" not in did(), "once")
    running("0.9")
    ok(run("load", "--again").returncode == 1 and "g++" in did(), "unless asked again")
    (tmp / "broken").unlink()
    (src / "globals.hpp").write_text("two")
    running("0.9")
    ok(run("load").returncode == 0 and plug.exists(), "or the source is another")
    running("0.9")
    ok(run("load", AEQUALYN_NO_FLOAT_DECORATIONS="1").returncode == 0 and did() == [], "not where decorations are off")

# what ships and calls it
ok((ROOT / "vendor/hyprbars/main.cpp").is_file() and (ROOT / "vendor/hyprbars/LICENSE").is_file(), "its source and license ship")
for f in ("bin/aequalyn-session-start", "config/hypr/keybinds.lua"):
    text = (ROOT / f).read_text()
    ok("aequalyn-hyprbars load" in text and "hyprctl plugin load" not in text, f + " uses it")

print(f"hyprbars: {fails} failures")
sys.exit(1 if fails else 0)
