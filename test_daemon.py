#!/usr/bin/env python3
import time
import socket
import sys
import os
import fcntl
import subprocess
import json
import codecs

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
        )

        print(f"-- Daemon started with PID {daemon_proc.pid}")
        # Close the socket in the parent process
        sock.close()
        yield daemon_proc
    finally:
        print(f"-- Terminating daemon with PID {daemon_proc.pid}")
        daemon_proc.terminate()
        print(f"-- Waiting for daemon to terminate")
        daemon_proc.wait()
        print(f"-- Daemon terminated")
        print(f"-- Removing socket file {SOCKET_PATH}")
        ensure_socket_deleted()
        

def main():
    print("--------------------------")
    print("Starting integration tests")
    print("--------------------------")

    with daemon():
        run_client_tests()

def run_client_tests():
    print(f"-- Running client tests against {SOCKET_PATH}")

    client_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client_sock.connect(SOCKET_PATH)

    # test list
    msg = 'list'
    msg_bytes = bytes(json.dumps(msg), encoding="utf-8")
    client_sock.send(msg_bytes)

    resp_bytes = client_sock.recv(1024)
    response = json.loads(resp_bytes.decode('utf-8'))
    expected = {'ok': {'timers': []}}

    if response != expected:
        print(f"sent: {msg}")
        print(f"expected: {expected}")
        print(f"received: {response}")
        sys.exit(1)

    print("-------------------")
    print("All tests passed")
    print("-------------------")
    client_sock.close()

if __name__ == "__main__":
    main()

