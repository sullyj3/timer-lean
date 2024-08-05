use std::os::fd::FromRawFd;
use std::os::fd::RawFd;
use std::os::unix;
use std::path::Path;
use std::path::PathBuf;

use dirs;

use crate::cli;
use crate::sand;

const SYSTEMD_SOCKFD: RawFd = 3;
const SOUND_FILENAME: &str = "timer_sound.opus";

fn xdg_sand_data_dir() -> Option<PathBuf> {
    Some(dirs::data_dir()?.join("sand"))
}

fn xdg_sound_path() -> Option<PathBuf> {
    Some(xdg_sand_data_dir()?.join(SOUND_FILENAME))
}

fn usrshare_sound_path() -> Option<PathBuf> {
    Some(Path::new("/usr/share/sand").join(SOUND_FILENAME))
}
    
fn sound_path() -> Option<PathBuf> {
    xdg_sound_path().or_else(|| usrshare_sound_path())
}

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

    let o_sound_path = sound_path();
    if o_sound_path.is_none() {
        eprintln!("Warning: failed to locate notification sound. Audio will not work");
    }

    let _listener = unsafe { unix::net::UnixListener::from_raw_fd(fd) };

    unimplemented!();
}
