"""Run with python3 tool/check_application_lock.py /path/to/dart.
Checks real process contention and OS cleanup after forced termination.
"""
import pathlib
import subprocess
import sys
import tempfile

probe = pathlib.Path(__file__).with_name('application_lock_probe.dart')
with tempfile.TemporaryDirectory(prefix='alikhlas-lock-') as directory:
    owner = subprocess.Popen(
        [sys.argv[1], str(probe), directory, 'hold'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert owner.stdout.readline().strip() == 'acquired'
        contender = subprocess.run(
            [sys.argv[1], str(probe), directory], capture_output=True,
            text=True, timeout=30,
        )
        assert contender.returncode == 23, (contender.stdout, contender.stderr)
        owner.kill()
        owner.wait(timeout=10)
        successor = subprocess.run(
            [sys.argv[1], str(probe), directory], capture_output=True,
            text=True, timeout=30,
        )
        assert successor.returncode == 0 and 'acquired' in successor.stdout, (
            successor.stdout, successor.stderr,
        )
        print('PASS: contender rejected, killed owner released lock, successor acquired')
    finally:
        if owner.poll() is None:
            owner.kill()
            owner.wait(timeout=10)
        for stream in (owner.stdin, owner.stdout, owner.stderr):
            stream.close()
