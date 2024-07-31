#!/usr/bin/env python3
import time
import socket
import sys
import os
import fcntl
import subprocess

def main():
    socket_path = "./test.sock"
    daemon_command = "./.lake/build/bin/sand"
    daemon_args = ["daemon"]

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    
    # Remove the socket file if it already exists
    try:
        os.unlink(socket_path)
    except OSError:
        if os.path.exists(socket_path):
            raise

    sock.bind(socket_path)
    sock.listen(1)

    flags = fcntl.fcntl(sock.fileno(), fcntl.F_GETFD)
    flags |= fcntl.FD_CLOEXEC
    fcntl.fcntl(sock.fileno(), fcntl.F_SETFD, flags)

    print(f"Python: Socket created at {socket_path} on fd {sock.fileno()}")

    daemon_proc = subprocess.Popen(
        [daemon_command] + daemon_args,
        pass_fds=(sock.fileno(),),
    )

    print(f"Python: Daemon started with PID {daemon_proc.pid}")

    # Close the socket in the parent process
    sock.close()

    run_client_tests(socket_path)

def run_client_tests(socket_path):
    print(f"Python: Running client tests against {socket_path}")

    client_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client_sock.connect(socket_path)
    client_sock.send(b'"list"')
    response = client_sock.recv(1024)
    print(f"Python: Received response: {response}")
    client_sock.close()

if __name__ == "__main__":
    main()

