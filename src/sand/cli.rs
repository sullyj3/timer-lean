use std::time::Duration;

use clap::{Args, Parser, Subcommand};

use crate::sand;

#[derive(Args)]
pub struct DaemonArgs {}

#[derive(Parser)]
#[clap(
    name = "sand",
    about = "Command line countdown timers that don't take up a terminal.",
    version
)]
pub struct Cli {
    #[clap(subcommand)]
    pub command: CliCommand,
}

#[derive(Args)]
pub struct StartArgs {
    #[clap(name = "DURATION", value_parser = sand::duration::parse_duration_component, num_args = 1..)]
    pub durations: Vec<Duration>,
}

#[derive(Subcommand)]
pub enum CliCommand {
    /// Start a new timer for the given duration
    Start(StartArgs),
    /// List active timers
    #[clap(alias = "list")]
    Ls,
    /// Pause the timer with the given ID
    Pause {
        timer_id: String,
    },
    /// Resume the timer with the given ID
    Resume {
        timer_id: String,
    },
    /// Cancel the timer with the given ID
    Cancel {
        timer_id: String,
    },
    Version,

    /// Launch the daemon
    Daemon(DaemonArgs),
}
