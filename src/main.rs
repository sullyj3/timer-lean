use clap::Parser;
use cli::CliCommand;

mod client;
mod daemon;
mod cli;

fn main() {
    let cli = cli::Cli::parse();

    match cli.command {
        CliCommand::Daemon(args) => daemon::main(args),
        _ => client::main(cli.command),
    }
    
}