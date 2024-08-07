use std::path::PathBuf;
use std::sync::Arc;
use std::sync::Mutex;
use std::time::Duration;
use std::time::Instant;

use tokio::sync::oneshot;
use tokio::sync::Notify;
use notify_rust::Notification;

use crate::sand::timer::TimerId;
use crate::sand::timer::Timer;
use crate::sand::timer::TimerInfoForClient;
use crate::sand::timers::Timers;

#[derive(Debug, Clone)]
pub struct DaemonCtx {
    next_id: Arc<Mutex<TimerId>>,
    timers: Arc<Timers>,
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

    pub fn get_timerinfo_for_client(&self, now: Instant) -> Vec<TimerInfoForClient> {
        self.timers.get_timerinfo_for_client(now)
    }
    
    pub fn add_timer(&self, now: Instant, duration: Duration) -> TimerId {
        let id = self.new_timer_id();
        let due = now + duration;
        
        // once the countdown has elapsed, it removes its associated timer from
        // the Timers map. For short durations (eg 0), We need to synchronize to 
        // ensure it doesn't do this til after it's been added
        let notify_added = Arc::new(Notify::new());
        let rx_added = notify_added.clone();
        let timers = self.timers.clone();
        let countdown = tokio::spawn(
            async move {
                tokio::time::sleep(duration).await;
                eprintln!("Timer {id} completed");
                Notification::new()
                    .summary("Time's up!")
                    .body("Your timer has elapsed")
                    .icon("alarm")
                    .urgency(notify_rust::Urgency::Critical)
                    .show()
                    .unwrap();
                // TODO play sound
                rx_added.notified().await;
                timers.elapse(id)
            }
        );
        self.timers.add(id, Timer::Running { due, countdown });
        notify_added.notify_one();
        id
    }
}