use crate::cli;

pub fn main(cmd: cli::CliCommand) {
    match cmd {
        cli::CliCommand::Start { duration } => {
            let duration_str = duration.join(" ");
            println!("Starting new timer for duration: {}", duration_str);
            // Implement timer creation functionality
        }
        cli::CliCommand::Ls => {
            println!("Listing timers...");
            // Implement list functionality
        }
        cli::CliCommand::Pause { timer_id } => {
            println!("Pausing timer {}...", timer_id);
            // Implement pause functionality
        }
        cli::CliCommand::Resume { timer_id } => {
            println!("Resuming timer {}...", timer_id);
            // Implement resume functionality
        }
        cli::CliCommand::Cancel { timer_id } => {
            println!("Cancelling timer {}...", timer_id);
            // Implement cancel functionality
        }
        cli::CliCommand::Daemon(_) => unreachable!(),
    }
}