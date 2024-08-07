
use std::sync::Arc;

use dashmap::{DashMap, Entry};

use crate::sand::timer::*;

#[derive(Default, Debug, Clone)]
pub struct Timers(Arc<DashMap<TimerId, Timer>>);

impl Timers{
    pub fn add(&self, id: TimerId, timer: Timer) {
        if let Some(t) = self.0.insert(id, timer) {
            unreachable!("BUG: adding timer with id #{id:?} clobbered pre-existing timer {t:?}");
        }
    }

    pub fn get_timerinfo_for_client(&self) -> Vec<TimerInfoForClient> {
        self.0.iter().map(|rm| {
            TimerInfoForClient::new(*rm.key(), rm.value())
        }).collect()
    }
    
    pub(crate) fn elapse(&self, id: TimerId) {
        let Entry::Occupied(occ) = self.0.entry(id) else {
            unreachable!("BUG: tried to complete nonexistent timer #{id:?}");
        };
        occ.remove();
    }
}