use std::env;

fn main() {

    let args: Vec<String> = env::args().collect();
    if args.len() > 1 && args[1] == "version" {
        println!("Sand v0.3.0: rewrite it in Rust");
    } else {
        println!("Hello, world!");
    }
}
