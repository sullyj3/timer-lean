pub mod state;

use std::io;
use std::io::Write;
use std::os::fd::FromRawFd;
use std::os::fd::RawFd;
use std::os::unix;
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::path::PathBuf;

use dirs;
use tokio;
use tokio::runtime::Runtime;
// use tokio::io::{AsyncReadExt, AsyncWriteExt};
use async_scoped;
use async_scoped::TokioScope;

use crate::cli;
use crate::sand;
use state::DaemonState;

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

async fn handle_client(mut stream: UnixStream) {
    // For now, pretend the client sent a list command
    let msg = "{ \"ok\": { \"timers\": [ ] } }";
    match stream.write_all(msg.as_bytes()) {
        Ok(_) => (),
        Err(e) => eprintln!("Error: failed to write to client: {}", e),
    }

    // Close the stream
    match stream.shutdown(std::net::Shutdown::Both) {
        Ok(_) => (),
        Err(e) => eprintln!("Error: failed to shutdown stream: {}", e),
    }
}

async fn daemon(fd: RawFd) -> io::Result<()> {
    let _state = DaemonState::default();
    let listener = unsafe { unix::net::UnixListener::from_raw_fd(fd) };

    let ((), _outputs) = async_scoped::TokioScope::scope_and_block(|scope: &mut TokioScope<()>| {
        loop {
            // Accept client
            match listener.accept() {
                Ok((stream, _addr)) => {
                    scope.spawn_cancellable(handle_client(stream), || ())
                },
                Err(e) => {
                    eprintln!("Error: failed to accept client: {}", e);
                    continue;
                }
            };
        }
    });
    Ok(())
}

pub fn main(_args: cli::DaemonArgs) -> io::Result<()> {
    println!("Starting sand daemon {}", sand::VERSION);

    let fd: RawFd = match env_fd() {
        None => {
            println!("SAND_SOCKFD not found, falling back on default.");
            SYSTEMD_SOCKFD
        }
        Some(fd) => {
            println!("Found SAND_SOCKFD.");
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
