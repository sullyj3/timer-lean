use std::io;

use clap::Parser;
use sand::cli::CliCommand;
use sand::cli;

mod client;
mod daemon;
mod sand;

fn main() -> io::Result<()> {
    let cli = cli::Cli::parse();

    match cli.command {
        CliCommand::Version => {
            println!("{}", sand::VERSION);
            Ok(())
        }
        CliCommand::Daemon(args) => daemon::main(args),
        _ => {
            client::main(cli.command)
        }
    }
}
