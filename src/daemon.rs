use std::os::fd::FromRawFd;
use std::os::fd::RawFd;
use std::os::unix;

use crate::cli;
use crate::sand;

const SYSTEMD_SOCKFD: RawFd = 3;

fn env_fd() -> Option<u32> {
    let str_fd = std::env::var("SAND_SOCKFD").ok()?;
    let fd = str_fd.parse::<u32>()
        .expect("Error: Found SAND_SOCKFD but couldn't parse it as a string")
        .into();
    Some(fd)
}

pub fn main(_args: cli::DaemonArgs) {
    println!("Starting sand daemon {}", sand::VERSION);

    let fd: RawFd = match env_fd() {
        None => {
            println!("SAND_SOCKFD not found, falling back on default.");
            SYSTEMD_SOCKFD
        },
        Some(fd) => {
            println!("Found SAND_SOCKFD.");
            fd.try_into().expect("Error: SAND_SOCKFD is too large to be a file descriptor.")
        },
    };

    let _listener = unsafe { unix::net::UnixListener::from_raw_fd(fd) };

    unimplemented!();
}
