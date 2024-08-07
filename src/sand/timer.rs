use std::{fmt::Display, time::{Duration, Instant}};

use serde::{Deserialize, Serialize};
use tokio::task::JoinHandle;


#[derive(PartialEq, Eq, Hash, Debug, Clone, Copy, Serialize, Deserialize)]
pub struct TimerId(u64);

impl Default for TimerId {
    fn default() -> Self {
        Self(1)
    }
}

impl Display for TimerId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "#{}", self.0)
    }
}

impl TimerId {
    pub fn next(self) -> Self {
        Self(self.0 + 1)
    }
}

#[derive(Debug)]
pub enum Timer {
    Paused { remaining: Duration },
    Running { due: Instant, countdown: JoinHandle<()>},
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct TimerInfoForClient;

impl TimerInfoForClient {
    pub fn new(_id: TimerId, _timer: &Timer) -> Self {
        Self
    }
}