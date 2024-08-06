use std::sync::Arc;
use std::sync::Mutex;


use crate::sand::timer::TimerId;
use crate::sand::timer::Timer;
use crate::sand::timers::Timers;

#[derive(Debug, Clone)]
pub struct DaemonState {
    nextId: Arc<Mutex<TimerId>>,
    timers: Timers,
}

impl Default for DaemonState {
    fn default() -> Self {
        Self {
            timers: Default::default(),
            nextId: Arc::new(Mutex::new(Default::default()))
        }
    }
}

impl DaemonState {
    fn new_timer_id(&self) -> TimerId {
        let mut curr = self.nextId.lock().unwrap();
        let id = *curr;
        *curr = curr.next();
        id
    }
}