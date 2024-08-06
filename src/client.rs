use crate::cli;

pub fn main(cmd: cli::CliCommand) {
    match cmd {
        cli::CliCommand::Start { duration } => {
            let duration_str = duration.join(" ");
            println!("Starting new timer for duration: {}", duration_str);
            todo!();
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
