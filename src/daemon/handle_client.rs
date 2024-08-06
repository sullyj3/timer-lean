
use std::time::Duration;
use std::time::Instant;

use serde_json::Error;
use tokio::io::AsyncBufReadExt;
use tokio::io::BufReader;
use tokio::net::UnixStream;
use tokio::io::AsyncWriteExt;
use tokio_stream::wrappers::LinesStream;
use tokio_stream::StreamExt;
use crate::sand::message::AddTimerResponse;
use crate::sand::message::CancelTimerResponse;
use crate::sand::message::ListResponse;
use crate::sand::message::PauseTimerResponse;
use crate::sand::message::ResumeTimerResponse;
use crate::sand::message::{Command, Response};

use super::state::DaemonState;

struct CmdHandlerCtx {
    now: Instant,
    state: DaemonState,
}

impl CmdHandlerCtx {
    fn new(state: DaemonState) -> Self {
        let now = Instant::now();
        Self { now, state }
    }

    fn list(&self) -> ListResponse {
        ListResponse::ok(self.state.get_timerinfo_for_client())
    }

    fn add_timer(&self, duration: u64) -> AddTimerResponse {
        let duration = Duration::from_millis(duration);
        let _now = self.now;
        AddTimerResponse::ok(self.state.add_timer(duration))
    }
    
    fn pause_timer(&self, _id: crate::sand::timer::TimerId) -> PauseTimerResponse {
        todo!()
    }
    
    fn resume_timer(&self, _id: crate::sand::timer::TimerId) -> ResumeTimerResponse {
        todo!()
    }
    
    fn cancel_timer(&self, _id: crate::sand::timer::TimerId) -> CancelTimerResponse {
        todo!()
    }
}


fn handle_command(cmd: Command, state: &DaemonState) -> Response {
    let ctx = CmdHandlerCtx::new(state.clone());
    match cmd {
        Command::List => ctx.list().into(),
        Command::AddTimer { duration } => ctx.add_timer(duration).into(),
        Command::PauseTimer(id) => ctx.pause_timer(id).into(),
        Command::ResumeTimer(id) => ctx.resume_timer(id).into(),
        Command::CancelTimer(id) => ctx.cancel_timer(id).into(),
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