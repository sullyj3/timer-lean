use std::sync::Arc;
use std::sync::Mutex;


use crate::sand::timer::TimerId;
use crate::sand::timer::Timer;
use crate::sand::timer::TimerInfoForClient;
use crate::sand::timers::Timers;

#[derive(Debug, Clone)]
pub struct DaemonState {
    next_id: Arc<Mutex<TimerId>>,
    timers: Timers,
}

impl Default for DaemonState {
    fn default() -> Self {
        Self {
            timers: Default::default(),
            next_id: Arc::new(Mutex::new(Default::default()))
        }
    }
}

impl DaemonState {
    pub fn new_timer_id(&self) -> TimerId {
        let mut curr = self.next_id.lock().unwrap();
        let id = *curr;
        *curr = curr.next();
        id
    }

    pub fn get_timerinfo_for_client(&self) -> Vec<TimerInfoForClient> {
        self.timers.get_timerinfo_for_client()
    }
    
    pub fn add_timer(&self, duration: std::time::Duration) -> TimerId {
        let id = self.new_timer_id();
        let timer = Timer; // TODO
        self.timers.add(id, timer);
        id
    }
}