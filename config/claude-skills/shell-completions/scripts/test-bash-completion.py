# /// script
# requires-python = ">=3.11"
# dependencies = ["pexpect"]
# ///
"""test-bash-completion.py <cmd.bash> <bash-binary> <cases.tsv> [--cwd DIR]

Runs every bash/both row of cases.tsv against the completion file under the given
bash. set_* asserts call bash-list.sh (non-interactive; emulates readline's word
splitting for that bash version). buf asserts drive a real interactive bash in a
pty (pexpect) and read the line buffer back after <TAB>. The bash32 column applies
when the binary is bash 3.x: `same`, `skip`, or `expect:<alternative>`.
Prints PASS/FAIL per case and `bash <version>  PASS n FAIL m`; exit 1 on any failure.
Needs a pty: run unsandboxed (`uv run test-bash-completion.py ...`).
"""

import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

import pexpect

HERE = Path(__file__).resolve().parent
ESC = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]|\r")


def parse_args(argv: list[str]) -> tuple[Path, str, Path, Path]:
    if len(argv) < 4:
        sys.exit(__doc__)
    comp, bash, cases = Path(argv[1]).resolve(), argv[2], Path(argv[3]).resolve()
    cwd = Path.cwd()
    rest = argv[4:]
    while rest:
        if rest[0] == "--cwd" and len(rest) > 1:
            cwd = Path(rest[1]).resolve()
            rest = rest[2:]
        else:
            sys.exit(f"unknown argument: {rest[0]}")
    return comp, bash, cases, cwd


def bash_version(bash: str) -> str:
    return subprocess.run(
        [bash, "--noprofile", "--norc", "-c", 'printf %s "$BASH_VERSION"'],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


def cmd_name(comp: Path) -> str:
    m = re.search(r"^complete\b.*\s(\S+)\s*$", comp.read_text(), re.M)
    return m.group(1) if m else comp.stem


def list_candidates(bash: str, comp: Path, cmd: str, line: str, cwd: Path) -> list[str]:
    r = subprocess.run(
        [bash, "--noprofile", "--norc", str(HERE / "bash-list.sh"), str(comp), cmd, line],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        return [f"<bash-list.sh exit {r.returncode}: {r.stderr.strip()}>"]
    # bash 3.2 branch appends the trailing space / directory slash itself: normalise for set asserts
    return [c.rstrip(" ").rstrip("/") for c in r.stdout.splitlines() if c.strip()]


def buffer_after_tab(bash: str, comp: Path, cwd: Path, typed: str) -> str:
    env = {
        "HOME": os.environ.get("HOME", "/"),
        "PATH": os.environ["PATH"],
        "TERM": "dumb",
        "INPUTRC": str(HERE / "inputrc"),
        "LANG": "en_US.UTF-8",
        "LC_ALL": "en_US.UTF-8",
    }
    c = pexpect.spawn(
        bash,
        ["--noprofile", "--norc", "-i"],
        env=env,
        cwd=str(cwd),
        dimensions=(40, 200),
        encoding="utf-8",
        timeout=10,
    )
    try:
        # markers are split so the echoed command text can never match them
        c.sendline(f"source {shlex.quote(str(comp))}; PS1='PR''OMPT> '; echo RE''ADY")
        c.expect(r"READY\r?\n")
        c.expect(r"PROMPT> ")
        c.send(typed + "\t")
        c.expect(pexpect.TIMEOUT, timeout=0.6)  # let readline finish inserting/listing
        c.send("\x01echo 'BU''F:<")  # C-a: line start
        c.send("\x05>'\r")  # C-e: line end, then run it
        c.expect(r"\r?\nBUF:<(.*)>\r?\n")
        return ESC.sub("", c.match.group(1))
    finally:
        c.close(force=True)


def main() -> int:
    comp, bash, cases, cwd = parse_args(sys.argv)
    version = bash_version(bash)
    major = int(version.split(".")[0])
    cmd = cmd_name(comp)
    passed = failed = 0
    for raw in cases.read_text().splitlines():
        if not raw or raw.startswith("#") or raw.startswith("id\t"):
            continue
        f = (raw.split("\t") + [""] * 7)[:7]
        cid, shell, line, assert_, expect, bash32, notes = f
        if shell not in ("bash", "both"):
            continue
        if assert_ in ("msg", "msg_not"):
            continue  # zsh-only asserts
        line = line.replace("{sp}", " ")
        expect = expect.replace("{sp}", " ")
        if major < 4:
            if bash32 == "skip":
                print(f"SKIP {cid}  {notes} (bash 3.x)")
                continue
            if bash32.startswith("expect:"):
                expect = bash32[len("expect:"):].replace("{sp}", " ")
        exp = [] if expect in ("", "-") else expect.split("|")
        if assert_ in ("buf", "buf_unchanged"):
            got = buffer_after_tab(bash, comp, cwd, line)
            want = line if assert_ == "buf_unchanged" else expect
            ok = got == want
            detail = f"buf=<{got}>"
        else:
            got_list = list_candidates(bash, comp, cmd, line, cwd)
            detail = f"list=[{'|'.join(sorted(got_list))}]"
            if assert_ == "set_eq":
                ok = sorted(got_list) == sorted(exp)
            elif assert_ == "set_empty":
                ok = not got_list
            elif assert_ == "set_has":
                ok = all(e in got_list for e in exp)
            elif assert_ == "set_not":
                ok = not any(e in got_list for e in exp)
            else:
                ok, detail = False, f"unknown assert '{assert_}'"
        if ok:
            passed += 1
            print(f"PASS {cid}  {notes}")
        else:
            failed += 1
            print(f"FAIL {cid}  {notes}")
            print(f"     typed: <{line}>  assert: {assert_}  expect: [{expect}]  {detail}")
    print(f"bash {version}  PASS {passed} FAIL {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
