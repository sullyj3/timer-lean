pub mod cli;
pub mod duration;
pub mod message;
pub mod timer;
pub mod timers;

pub const VERSION: &str = "Sand v0.3.0: rewrite it in Rust";

pub mod audio {
    use std::convert::AsRef;
    use std::fmt::Debug;
    use std::io::BufReader;
    use std::io::{self, Read};
    use std::path::Path;
    use std::sync::Arc;

    use rodio;
    use rodio::PlayError;

    // thanks sinesc
    // https://github.com/RustAudio/rodio/issues/141#issuecomment-383371609
    #[derive(Clone)]
    pub struct Sound(Arc<[u8]>);

    impl AsRef<[u8]> for Sound {
        fn as_ref(&self) -> &[u8] {
            &self.0
        }
    }

    impl Sound {
        pub fn load<P>(path: P) -> io::Result<Sound>
        where
            P: AsRef<Path> + Debug,
        {
            use std::fs::File;
            let mut buf = Vec::new();
            let mut file = File::open(path)?;
            file.read_to_end(&mut buf)?;
            Ok(Sound(Arc::from(buf)))
        }

        pub fn cursor(self: &Self) -> io::Cursor<Sound> {
            io::Cursor::new(self.clone())
        }

        pub fn decoder(self: &Self) -> rodio::Decoder<io::Cursor<Sound>> {
            rodio::Decoder::new(self.cursor()).unwrap()
        }

        pub fn play(&self) {
            let decoder = self.decoder();
            tokio::spawn(async move {
                let (_stream, handle) = rodio::OutputStream::try_default().unwrap();
                let sink = rodio::Sink::try_new(&handle).unwrap();
                sink.append(decoder);
                sink.sleep_until_end();
            });
            eprintln!("notification sound");
        }
    }
}
