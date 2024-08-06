mod state;
mod handle_client;

use std::str;
use std::io;
use std::os::fd::FromRawFd;
use std::os::fd::RawFd;
use std::os::unix;
use std::path::Path;
use std::path::PathBuf;

use dirs;
use tokio;
use tokio::net::UnixListener;
use tokio::runtime::Runtime;
use async_scoped;
use async_scoped::TokioScope;

use crate::cli;
use crate::sand;
use state::DaemonState;
use handle_client::handle_client;

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
    let fd = str_fd
        .parse::<u32>()
        .expect("Error: Found SAND_SOCKFD but couldn't parse it as a string")
        .into();
    Some(fd)
}

async fn accept_loop(listener: UnixListener) {
    eprintln!("starting accept loop");
    loop {
        match listener.accept().await {
            Ok((stream, _addr)) => {
                eprintln!("got client");
                let _jh = tokio::spawn(handle_client(stream));
            },
            Err(e) => {
                eprintln!("Error: failed to accept client: {}", e);
                continue;
            }
        };
    }
}

async fn daemon(fd: RawFd) -> io::Result<()> {
    eprintln!("daemon started.");
    let _state = DaemonState::default();
    let std_listener: unix::net::UnixListener = unsafe { unix::net::UnixListener::from_raw_fd(fd) };
    std_listener.set_nonblocking(true)?;
    let listener: UnixListener = UnixListener::from_std(std_listener)?;

    TokioScope::scope_and_block(|scope | {
        scope.spawn(accept_loop(listener));
    });

    Ok(())
}

pub fn main(_args: cli::DaemonArgs) -> io::Result<()> {
    eprintln!("Starting sand daemon {}", sand::VERSION);

    let fd: RawFd = match env_fd() {
        None => {
            eprintln!("SAND_SOCKFD not found, falling back on default.");
            SYSTEMD_SOCKFD
        }
        Some(fd) => {
            eprintln!("Found SAND_SOCKFD.");
            fd.try_into()
                .expect("Error: SAND_SOCKFD is too large to be a file descriptor.")
        }
    };

    let o_sound_path = sound_path();
    if o_sound_path.is_none() {
        eprintln!("Warning: failed to locate notification sound. Audio will not work");
    }

    let rt = Runtime::new()?;
    rt.block_on(daemon(fd))
}
