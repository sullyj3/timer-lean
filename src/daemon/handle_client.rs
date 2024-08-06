
use std::time::Duration;

use serde_json::Error;
use tokio::io::AsyncBufReadExt;
use tokio::io::BufReader;
use tokio::net::UnixStream;
use tokio::io::AsyncWriteExt;
use tokio_stream::wrappers::LinesStream;
use tokio_stream::StreamExt;
use crate::sand::message::AddTimerResponse;
use crate::sand::message::ListResponse;
use crate::sand::message::{Command, Response};

use super::state::DaemonState;

fn list(state: &DaemonState) -> ListResponse {
    ListResponse::ok(state.get_timerinfo_for_client())
}

fn add_timer(state: &DaemonState, duration: u64) -> AddTimerResponse {
    let duration = Duration::from_millis(duration);
    AddTimerResponse::ok(state.add_timer(duration))
}

fn handle_command(cmd: Command, state: &DaemonState) -> Response {
    match cmd {
        Command::List => list(state).into(),
        Command::AddTimer { duration } => add_timer(state, duration).into()
    }
}


pub async fn handle_client(mut stream: UnixStream, state: DaemonState) {
    eprintln!("DEBUG: handling client.");

    let (read_half, mut write_half) = stream.split();

    let br = BufReader::new(read_half);

    let mut lines = LinesStream::new(br.lines());

    while let Some(rline) = lines.next().await {
        let line: String = match rline {
            Ok(line) => line,
            Err(e) => {
                eprintln!("Error reading line from client: {e}");
                continue;
            },
        };
        let line: &str = line.trim();
        let rcmd: Result<Command, Error> = serde_json::from_str(&line);

        let resp: Response = match rcmd {
            Ok(cmd) => handle_command(cmd, &state),
            Err(e) => {
                let err_msg: String = format!("Error: failed to parse client message as Command: {e}"); 
                eprintln!("{err_msg}");
                Response::Error(err_msg)
            }
        };
        let resp_str: String = serde_json::to_string(&resp).unwrap();
        write_half.write_all(resp_str.as_bytes()).await.unwrap();
    }

    eprintln!("Client disconnected");
}