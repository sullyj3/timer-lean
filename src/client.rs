
use std::io::{self, BufRead, BufReader, BufWriter, LineWriter, Write};
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::os::unix::net::UnixStream;

use dirs;
use serde::Deserialize;

use crate::cli;
use crate::sand::message::{AddTimerResponse, Command};

fn get_sock_path() -> Option<PathBuf> {
    if let Ok(path) = std::env::var("SAND_SOCK_PATH") {
        Some(path.into())
    } else {
        Some(dirs::runtime_dir()?.join("sand.sock"))
    }
}

fn parse_durations(strs: &[String]) -> u64 {
    // todo 
    2000
}

struct DaemonConnection {
    read: BufReader<UnixStream>,
    write: LineWriter<UnixStream>,
}

impl DaemonConnection {
    fn new(sock_path: PathBuf) -> io::Result<Self> {
        let stream = UnixStream::connect(sock_path)?;

        let read = BufReader::new(stream.try_clone()?);
        let write = LineWriter::new(stream);

        Ok(Self { read, write })
    }

    fn send(&mut self, cmd: Command) -> io::Result<()> {
        let str = serde_json::to_string(&cmd).expect("failed to serialize Command {cmd}");
        writeln!(self.write, "{str}")
    }

    fn recv<T: for<'de> Deserialize<'de>>(&mut self) -> io::Result<T> {
        let mut recv_buf = String::with_capacity(128);
        self.read.read_line(&mut recv_buf)?;
        let resp: T = serde_json::from_str(&recv_buf).expect(
            "Bug: failed to deserialize response from daemon"
        );
        Ok(resp)
    }
}

pub fn main(cmd: cli::CliCommand) -> io::Result<()> {
    let Some(sock_path) = get_sock_path() else {
        eprintln!("socket not provided and runtime directory does not exist.");
        eprintln!("no socket to use.");
        std::process::exit(1)
    };
    
    let mut conn = match DaemonConnection::new(sock_path) {
        Ok(conn) => conn,
        Err(e) => {
            eprintln!("Error establishing connection with daemon: {e}");
            std::process::exit(1);
        },
    };

    match cmd {
        cli::CliCommand::Start { duration } => {
            let duration = parse_durations(&duration);
            conn.send(Command::AddTimer { duration: duration })?;
            let AddTimerResponse::Ok { id } = conn.recv::<AddTimerResponse>()?;
            // TODO format duration
            println!(
                "Timer {id} created for {duration}."
            );
            Ok(())
        }
        cli::CliCommand::Ls => {
            println!("Listing timers...");
            todo!();
        }
        cli::CliCommand::Pause { timer_id } => {
            println!("Pausing timer {}...", timer_id);
            todo!();
        }
        cli::CliCommand::Resume { timer_id } => {
            println!("Resuming timer {}...", timer_id);
            todo!();
        }
        cli::CliCommand::Cancel { timer_id } => {
            println!("Cancelling timer {}...", timer_id);
            todo!();
        }
        cli::CliCommand::Version => unreachable!("handled in top level main"),
        cli::CliCommand::Daemon(_) => unreachable!("handled in top level main"),
    }
}
