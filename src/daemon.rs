use crate::cli;
use crate::sand;

pub fn main(_args: cli::DaemonArgs) {
    println!("Starting sand daemon {}", sand::VERSION);
}