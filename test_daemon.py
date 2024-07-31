#!/usr/bin/env python3

'''
Sand integration tests.

If this gets too convoluted, we'll switch to a proper test framework.
'''

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

failure = False

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
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
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
        # wait a moment for the daemon to start
        time.sleep(0.1)
        run_client_tests()

@contextmanager
def client_socket():
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client_sock:
        client_sock.connect(SOCKET_PATH)
        yield client_sock

def test_msg_and_response(test_name, msg, expected):
    global failure
    try:
        msg_bytes = bytes(json.dumps(msg), encoding='utf-8')

        with client_socket() as client_sock:
            client_sock.send(msg_bytes)
            resp_bytes = client_sock.recv(1024)

        response = json.loads(resp_bytes.decode('utf-8'))

        if response != expected:
            print()
            print(f'-- test {test_name} failed.')
            print(f'sent: {msg}')
            print(f'expected: {expected}')
            print(f'received: {response}')

            failure = True
            print('❌', end='', flush=True)
            return

        print('✔️', end='', flush=True)
    except Exception as e:
        print()
        print(f'-- test {test_name} failed.')
        print(f'sent: {msg}')
        print(f'expected: {expected}')
        print(f'but got exception: {e}')

        failure = True
        print('❌', end='', flush=True)
        return

'''
format for tests:
{
    'test_name': Name of the test,
    'msg':       Message to send to the daemon. Will be serialised with 
                 json.dumps().
    'expected':  Expected response from the daemon. Will be deserialised with 
                 json.loads().
}
'''
test_cases = [
    {
        'test_name': 'list',
        'msg': 'list',
        'expected': {'ok': {'timers': []}}
    },
    {
        'test_name': 'add',
        'msg': {'addTimer': {'duration': {'millis': 60000}}},
        'expected': 'ok'
    },
]

def run_client_tests():
    print(f'-- Running client tests against {SOCKET_PATH}...')

    for test_case in test_cases:
        test_msg_and_response(**test_case)
    print()

    if failure:
        print("-------------------")
        print("Some tests failed")
        print("-------------------")
        sys.exit(1)
    else:
        print("-------------------")
        print("All tests passed")
        print("-------------------")

if __name__ == "__main__":
    main()

