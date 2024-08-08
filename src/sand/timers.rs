
use std::time::Instant;

use dashmap::{DashMap, Entry};

use crate::sand::timer::*;

#[derive(Default, Debug)]
pub struct Timers(DashMap<TimerId, Timer>);

impl Timers{
    pub fn add(&self, id: TimerId, timer: Timer) {
        if let Some(t) = self.0.insert(id, timer) {
            unreachable!("BUG: adding timer with id #{id:?} clobbered pre-existing timer {t:?}");
        }
    }

    pub fn get_timerinfo_for_client(&self, now: Instant) -> Vec<TimerInfoForClient> {
        self.0.iter().map(|ref_multi| {
            let (id, timer) = ref_multi.pair();
            TimerInfoForClient::new(*id, timer, now)
        }).collect()
    }
    
    pub(crate) fn elapse(&self, id: TimerId) {
        let Entry::Occupied(occ) = self.0.entry(id) else {
            unreachable!("BUG: tried to complete nonexistent timer #{id:?}");
        };
        occ.remove();
    }
}