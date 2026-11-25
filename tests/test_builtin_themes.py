#!/usr/bin/env python3
"""python3 tests/test_builtin_themes.py -- the built-in themes of an installed system"""
import os, pathlib, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOL = ROOT / "bin/aequalyn-builtin-themes"
fails = 0


def ok(cond, what):
    global fails
    if not cond:
        fails += 1
        print("FAIL", what)


def git(d, *args):
    subprocess.run(["git", "-C", str(d), "-c", "user.name=t", "-c", "user.email=t@t", *args], check=True, capture_output=True)


with tempfile.TemporaryDirectory() as tmp:
    tmp = pathlib.Path(tmp)
    pub = tmp / "git/aequalyn-themes.git"
    for t in ("aequalyn", "one", "one-day", "other"):
        (pub / "themes" / t / "backgrounds").mkdir(parents=True)
        (pub / "themes" / t / "theme.json").write_text('{"name": "%s"}' % t)
    (pub / "builtin.list").write_text("# a comment\naequalyn\none\none-day  # night and day\n../one\nmissing\n\n")
    git(pub, "init", "-q", "-b", "main")
    git(pub, "add", "-A")
    git(pub, "commit", "-q", "-m", "t")
    root, src = tmp / "share", tmp / "lib/src"
    (root / "themes/aequalyn").mkdir(parents=True)
    (root / "themes/aequalyn/mine").write_text("x")
    env = dict(os.environ, AEQUALYN_ROOT=str(root), AEQUALYN_SRC=str(src), AEQUALYN_GIT="file://%s" % (tmp / "git"))

    def run(*args, script=TOOL, **extra):
        return subprocess.run(["unshare", "-r", "bash", str(script), *args], env=dict(env, **extra), capture_output=True, text=True, timeout=60)

    def there():
        return sorted(p.name for p in (root / "themes").iterdir())

    ok(subprocess.run(["bash", str(TOOL)], env=env, capture_output=True).returncode == 1, "not without root")
    ok(run().returncode == 0 and there() == ["aequalyn"], "nothing to link without a clone")
    ok(run("--fetch", AEQUALYN_GIT="file:///nowhere").returncode != 0, "no internet: it fails, to be tried again")
    ok(not (src / "aequalyn-themes").exists() and not list(src.glob(".themes*")), "and leaves nothing behind")
    r = run("--fetch")
    ok(r.returncode == 0, "it fetches: " + r.stderr)
    ok(there() == ["aequalyn", "one", "one-day"], "the built-in ones, no other: %s" % there())
    ok((root / "themes/one").is_symlink() and (root / "themes/one/theme.json").is_file(), "as links")
    ok((root / "themes/aequalyn/mine").is_file() and not (root / "themes/aequalyn").is_symlink(), "a folder of its own is left alone")
    # the picker finds them through the links
    home = tmp / "home"
    home.mkdir()
    text = (ROOT / "bin/aequalyn-themes").read_text().replace("/usr/share/aequalyn/themes", str(root / "themes"))
    (tmp / "aequalyn-themes").write_text(text)
    r = subprocess.run(["bash", str(tmp / "aequalyn-themes"), "list"], env={"HOME": str(home), "PATH": os.environ["PATH"]}, capture_output=True, text=True)
    ok([x.split()[0] for x in r.stdout.splitlines()] == ["aequalyn", "one", "one-day"], "listed: " + r.stdout + r.stderr)
    # a theme that is gone, and a link that is not ours
    (root / "themes/theirs").symlink_to("/nowhere")
    (src / "aequalyn-themes/builtin.list").write_text("one\n")
    subprocess.run(["rm", "-r", str(src / "aequalyn-themes/themes/one-day")], check=True)
    ok(run().returncode == 0 and there() == ["aequalyn", "one", "theirs"], "a theme that is gone goes: %s" % there())
    # the migration, and the live ISO
    (root / "bin").mkdir()
    subprocess.run(["cp", str(TOOL), str(root / "bin")], check=True)
    (root / "themes/one").unlink()
    ok(run(script=ROOT / "migrations/20261125-2.sh").returncode == 0 and "one" in there(), "the migration links them")
    live = tmp / "live"
    live.mkdir()
    (live / "themes").symlink_to(root / "themes")
    (root / "themes/one").unlink()
    ok(run("--fetch", AEQUALYN_ROOT=str(live)).returncode == 0 and "one" not in there(), "not on the live ISO")

print(f"builtin themes: {fails} failures")
sys.exit(1 if fails else 0)
