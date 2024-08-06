use serde::{Deserialize, Serialize};


#[derive(PartialEq, Eq, Hash, Debug, Clone, Copy)]
pub struct TimerId(u64);

impl Default for TimerId {
    fn default() -> Self {
        Self(1)
    }
}

impl TimerId {
    pub fn next(self) -> Self {
        Self(self.0 + 1)
    }
}

#[derive(Debug)]
pub struct Timer;

#[derive(Debug, PartialEq, Serialize, Deserialize)]
pub struct TimerInfoForClient;

impl TimerInfoForClient {
    pub fn new(id: TimerId, timer: &Timer) -> Self {
        Self
    }
}