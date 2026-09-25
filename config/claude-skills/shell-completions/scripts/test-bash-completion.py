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
Cases run in parallel (COMPLETION_JOBS, default 6), one fresh shell each; output stays in order.
Needs a pty: run unsandboxed (`uv run test-bash-completion.py ...`).
"""

import os
import re
import shlex
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
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
    # the name after `-F <function>`; the line may be indented (if/else) or carry a comment
    m = re.search(r"^[ \t]*complete\b[^\n#]*-F[ \t]+\S+[ \t]+([^\s#;]+)", comp.read_text(), re.M)
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
    # the bash 3.2 branch appends the trailing space / directory slash and printf-%q-quotes file
    # names itself: normalise to the bare name for set asserts (buf asserts see the real insertion)
    return [re.sub(r"\\(.)", r"\1", c.rstrip(" ").rstrip("/")) for c in r.stdout.splitlines() if c.strip()]


def buffer_after_tab(bash: str, comp: Path, cwd: Path, typed: str) -> str:
    env = {
        "HOME": os.environ.get("HOME", "/"),
        "HISTFILE": "/dev/null",  # an interactive bash would append to (and trim) ~/.bash_history
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
        # readline handles keys in order: the TAB completes before C-a runs, no wait needed
        c.send(typed + "\t")
        c.send("\x01echo 'BU''F:<")  # C-a: line start
        c.send("\x05>'\r")  # C-e: line end, then run it
        c.expect(r"\r?\nBUF:<(.*)>\r?\n")
        return ESC.sub("", c.match.group(1))
    finally:
        c.close(force=True)


def run_case(row: list[str], major: int, bash: str, comp: Path, cmd: str, cwd: Path) -> tuple[str, bool | None]:
    cid, _shell, line, assert_, expect, bash32, notes = row
    line = line.replace("{sp}", " ")
    expect = expect.replace("{sp}", " ")
    if major < 4:
        if bash32 == "skip":
            return f"SKIP {cid}  {notes} (bash 3.x)", None
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
        return f"PASS {cid}  {notes}", True
    return f"FAIL {cid}  {notes}\n     typed: <{line}>  assert: {assert_}  expect: [{expect}]  {detail}", False


def main() -> int:
    comp, bash, cases, cwd = parse_args(sys.argv)
    version = bash_version(bash)
    major = int(version.split(".")[0])
    cmd = cmd_name(comp)
    rows = []
    for raw in cases.read_text().splitlines():
        if not raw or raw.startswith("#") or raw.startswith("id\t"):
            continue
        f = (raw.split("\t") + [""] * 7)[:7]
        if f[1] not in ("bash", "both") or f[3] in ("msg", "msg_not"):  # msg asserts are zsh-only
            continue
        rows.append(f)
    jobs = int(os.environ.get("COMPLETION_JOBS", "6"))
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        results = list(pool.map(lambda r: run_case(r, major, bash, comp, cmd, cwd), rows))
    passed = sum(1 for _, ok in results if ok)
    failed = sum(1 for _, ok in results if ok is False)
    for text, _ in results:
        print(text)
    print(f"bash {version}  PASS {passed} FAIL {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
