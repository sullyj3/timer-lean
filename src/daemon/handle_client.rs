
use serde_json::Error;
use tokio::io::AsyncBufReadExt;
use tokio::io::BufReader;
use tokio::net::UnixStream;
use tokio::io::AsyncWriteExt;
use tokio_stream::wrappers::LinesStream;
use tokio_stream::StreamExt;
use crate::sand::message::{Command, ListResponse};

use super::state::DaemonState;

fn list(state: &DaemonState) -> ListResponse {
    ListResponse::Ok{timers: state.get_timerinfo_for_client()}
}

fn handle_command(cmd: Command, state: &DaemonState) -> String {
    match cmd {
        Command::List => {
            let response = list(state);
            serde_json::to_string(&response).unwrap()
        }
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

        let reply = match rcmd {
            Ok(cmd) => &handle_command(cmd, &state),
            Err(e) => {
                eprintln!("Error: failed to parse client message as Command: {e}");
                "{ \"error\": \"unknown command\" }"
            }
        };

        write_half.write_all(reply.as_bytes()).await.unwrap();
    }

    eprintln!("Client disconnected");
}