use std::path::PathBuf;
use std::sync::Arc;
use std::sync::Mutex;

use crate::sand::timer::TimerId;
use crate::sand::timer::Timer;
use crate::sand::timer::TimerInfoForClient;
use crate::sand::timers::Timers;

#[derive(Debug, Clone)]
pub struct DaemonCtx {
    next_id: Arc<Mutex<TimerId>>,
    timers: Timers,
    sound_path: Option<PathBuf>,
}

impl DaemonCtx {
    pub fn new(sound_path: Option<PathBuf>) -> Self {
        Self {
            timers: Default::default(),
            next_id: Arc::new(Mutex::new(Default::default())),
            sound_path
        }
    }

    pub fn new_timer_id(&self) -> TimerId {
        let mut curr = self.next_id.lock().unwrap();
        let id = *curr;
        *curr = curr.next();
        id
    }

    pub fn get_timerinfo_for_client(&self) -> Vec<TimerInfoForClient> {
        self.timers.get_timerinfo_for_client()
    }
    
    pub fn add_timer(&self, _duration: std::time::Duration) -> TimerId {
        let id = self.new_timer_id();
        let timer = Timer; // TODO
        self.timers.add(id, timer);
        id
    }
}