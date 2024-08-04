#!/usr/bin/env python3

'''
Sand integration tests.
'''

import time
import socket
import sys
import os
import fcntl
import subprocess
import json
import warnings
from contextlib import contextmanager
from pprint import pformat

import pytest
from deepdiff import DeepDiff

SOCKET_PATH = "./test.sock"

'''
Remove the socket file if it already exists
'''
def ensure_deleted(path):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass

@pytest.fixture
def daemon_socket():
    ensure_deleted(SOCKET_PATH)

    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.bind(SOCKET_PATH)
            sock.listen(1)
            
            flags = fcntl.fcntl(sock.fileno(), fcntl.F_GETFD)
            flags |= fcntl.FD_CLOEXEC
            fcntl.fcntl(sock.fileno(), fcntl.F_SETFD, flags)

            print(f"-- Socket created at {SOCKET_PATH} on fd {sock.fileno()}")
            yield sock
    finally:
        print(f"-- Removing socket file {SOCKET_PATH}")
        ensure_deleted(SOCKET_PATH)

@pytest.fixture
def daemon(daemon_socket):

    daemon_command = "./.lake/build/bin/sand"
    daemon_args = ["daemon"]
    sock_fd = daemon_socket.fileno()
    try:
        daemon_proc = subprocess.Popen(
            [daemon_command] + daemon_args,
            pass_fds=(sock_fd,),
            env={"SAND_SOCKFD": str(sock_fd)},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        print(f"-- Daemon started with PID {daemon_proc.pid}")
        # Close the socket in the parent process
        daemon_socket.close()
        yield daemon_proc
    finally:
        print(f"-- Terminating daemon with PID {daemon_proc.pid}")
        daemon_proc.terminate()
        print(f"-- Waiting for daemon to terminate")
        daemon_proc.wait()
        print(f"-- Daemon terminated")

def run_client(sock_path, args):
    command = "./.lake/build/bin/sand"

    client_proc = subprocess.Popen(
        [command] + args,
        env={"SAND_SOCK_PATH": sock_path},
        stdout=subprocess.PIPE,
    )
    status = client_proc.wait()
    output = client_proc.stdout.read().decode('utf-8')
    return (status, output)

class TestClient:
    def test_list_none(self, daemon):
        (status, output) = run_client(SOCKET_PATH, ["list"])
        assert status == 0, f"Client exited with status {status}"
        expected_stdout = "No running timers."
        assert output.strip() == expected_stdout

    def test_add(self, daemon):
        (status, output) = run_client(SOCKET_PATH, ["10m"])
        assert status == 0, f"Client exited with status {status}"
        expected_stdout = "Timer #1 created for 00:10:00:000."
        assert output.strip() == expected_stdout

@contextmanager
def client_socket():
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client_sock:
        client_sock.connect(SOCKET_PATH)
        yield client_sock

def msg_and_response(msg):
    msg_bytes = bytes(json.dumps(msg), encoding='utf-8')
    with client_socket() as sock:
        sock.send(msg_bytes)
        resp_bytes = sock.recv(1024)
    response = json.loads(resp_bytes.decode('utf-8'))
    return response

# Since the amount of time elapsed is not deterministic, for most tests we want
# to ignore the specific amount of time elapsed/remaining.
IGNORE_MILLIS = r".+\['millis'\]$"

class TestDaemon:
    def test_add(self, daemon):
        msg = {'addTimer': {'duration': {'millis': 60000}}} 
        expected = {'ok': {'createdId': {'id': 1}}}

        response = msg_and_response(msg)
        diff = DeepDiff(expected, response, ignore_order=True)
        assert not diff, f"Response shape mismatch:\n{pformat(diff)}"

    def test_list(self, daemon):
        run_client(SOCKET_PATH, ["10m"])
        run_client(SOCKET_PATH, ["20m"])
        
        response = msg_and_response('list')

        expected_shape = {
            'ok': {
                'timers': [
                    {'id': {'id': 2}, 'state': {'running': {'due': {'millis': 0 }}}},
                    {'id': {'id': 1}, 'state': {'running': {'due': {'millis': 0 }}}},
                ]
            }
        }
        
        diff = DeepDiff(
            expected_shape,
            response,
            exclude_regex_paths=IGNORE_MILLIS,
            ignore_order=True
        )
        assert not diff, f"Response shape mismatch:\n{pformat(diff)}"

    def test_pause_resume(self, daemon):
        run_client(SOCKET_PATH, ["10m"])
        run_client(SOCKET_PATH, ["pause", "1"])

        response = msg_and_response('list')
        expected_shape = {
            'ok': {
                'timers': [
                    {
                        'id': {'id': 1},
                        'state': {'paused': {'remaining': {'millis': 0}}}
                    }
                ]
            }
        }
        diff = DeepDiff(
            expected_shape,
            response,
            exclude_regex_paths=IGNORE_MILLIS,
            ignore_order=True
        )
        assert not diff, f"Response shape mismatch:\n{pformat(diff)}"

        run_client(SOCKET_PATH, ["resume", "1"])

        response = msg_and_response('list')
        expected_shape = {
            'ok': {
                'timers': [
                    {
                        'id': {'id': 1},
                        'state': {'running': {'due': {'millis': 0}}}
                    }
                ]
            }
        }
        diff = DeepDiff(
            expected_shape,
            response,
            exclude_regex_paths=IGNORE_MILLIS,
            ignore_order=True
        )
        assert not diff, f"Response shape mismatch:\n{pformat(diff)}"

    def test_cancel(self, daemon):
        run_client(SOCKET_PATH, ["10m"])
        run_client(SOCKET_PATH, ["cancel", "1"])

        response = msg_and_response('list')
        expected_shape = { 'ok': { 'timers': [] } }
        diff = DeepDiff(
            expected_shape,
            response,
            ignore_order=True
        )
        assert not diff, f"Response shape mismatch:\n{pformat(diff)}"

'''
Need to get this down. I think by eliminating any `import Lean`.
Hopefully we'll be able to make the warn_threshold the fail_threshold
'''
def test_executable_size():
    exe_size = os.path.getsize("./.lake/build/bin/sand")
    warn_threshold = 15_000_000
    if exe_size > warn_threshold:
        exe_size_mb = exe_size / 1_000_000
        warnings.warn(f"Sand executable size is {exe_size_mb:.2f}MB")
    
    fail_threshold = 100_000_000
    assert exe_size < fail_threshold, f"Sand executable size is {exe_size_mb:.2f}MB"

if __name__ == "__main__":
    pytest.main([__file__])
