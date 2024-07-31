#!/usr/bin/env python3

'''
Sand integration tests.

TODO:
- take better advantage of pytest's features, eg fixtures
- try make it a bit faster
'''

import time
import socket
import sys
import os
import fcntl
import subprocess
import json
import pytest

from contextlib import contextmanager

SOCKET_PATH = "./test.sock"

'''
Remove the socket file if it already exists
'''
def ensure_socket_deleted():
    try:
        os.unlink(SOCKET_PATH)
    except FileNotFoundError:
        pass

'''
Ensures when the context manager exits:
- the daemon process is terminated 
- the socket file is removed

(assuming we're not killed with SIGKILL)
'''
@contextmanager
def daemon():
    ensure_socket_deleted()

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.bind(SOCKET_PATH)
    sock.listen(1)

    flags = fcntl.fcntl(sock.fileno(), fcntl.F_GETFD)
    flags |= fcntl.FD_CLOEXEC
    fcntl.fcntl(sock.fileno(), fcntl.F_SETFD, flags)

    print(f"-- Socket created at {SOCKET_PATH} on fd {sock.fileno()}")

    daemon_command = "./.lake/build/bin/sand"
    daemon_args = ["daemon"]
    try:
        daemon_proc = subprocess.Popen(
            [daemon_command] + daemon_args,
            pass_fds=(sock.fileno(),),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        print(f"-- Daemon started with PID {daemon_proc.pid}")
        # Close the socket in the parent process
        sock.close()

        # Read stdout and stderr
        stdout, stderr = daemon_proc.communicate(timeout=1)
        if stdout:
            print(f"-- Daemon stdout:\n{stdout.decode()}")
        if stderr:
            print(f"-- Daemon stderr:\n{stderr.decode()}")

        yield daemon_proc
    except Exception as e:
        print(f"-- Error starting daemon: {e}")
    finally:
        print(f"-- Terminating daemon with PID {daemon_proc.pid}")
        daemon_proc.terminate()
        print(f"-- Waiting for daemon to terminate")
        daemon_proc.wait()
        print(f"-- Daemon terminated")
        print(f"-- Removing socket file {SOCKET_PATH}")
        ensure_socket_deleted()


@contextmanager
def client_socket():
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client_sock:
        client_sock.connect(SOCKET_PATH)
        yield client_sock

def msg_and_response(msg):
    msg_bytes = bytes(json.dumps(msg), encoding='utf-8')

    with client_socket() as client_sock:
        client_sock.send(msg_bytes)
        resp_bytes = client_sock.recv(1024)

    response = json.loads(resp_bytes.decode('utf-8'))
    return response

def test_list():
    with daemon():
        time.sleep(1)  # Increased sleep duration
        msg = 'list'
        expected = {'ok': {'timers': []}}
        response = msg_and_response(msg)
        assert response == expected, f"Test 'list' failed. Expected {expected}, got {response}"

def test_add():
    with daemon():
        time.sleep(1)  # Increased sleep duration
        msg = {'addTimer': {'duration': {'millis': 60000}}}
        expected = 'ok'
        response = msg_and_response(msg)
        assert response == expected, f"Test 'add' failed. Expected {expected}, got {response}"

if __name__ == "__main__":
    pytest.main([__file__])
