
use std::io::{self, BufRead, BufReader, LineWriter, Write};
use std::path::PathBuf;
use std::os::unix::net::UnixStream;
use std::time::Duration;

use dirs;
use serde::Deserialize;

use crate::sand::cli::StartArgs;
use crate::cli;
use crate::sand::message::{AddTimerResponse, Command};
use crate::sand::duration::DurationExt;

fn get_sock_path() -> Option<PathBuf> {
    if let Ok(path) = std::env::var("SAND_SOCK_PATH") {
        Some(path.into())
    } else {
        Some(dirs::runtime_dir()?.join("sand.sock"))
    }
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
        cli::CliCommand::Start(StartArgs{ durations }) => {
            let dur: Duration = durations.iter().sum();
            conn.send(Command::AddTimer { duration: dur.as_millis() as u64 })?;
            let AddTimerResponse::Ok { id } = conn.recv::<AddTimerResponse>()?;
            
            let dur_string = dur.format_colon_separated();
            println!("Timer {id} created for {dur_string}.");
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
