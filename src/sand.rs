pub mod cli;
pub mod message;
pub mod timer;
pub mod timers;

pub const VERSION: &str = "Sand v0.3.0: rewrite it in Rust";

pub mod duration {
    use std::time::Duration;
    use std::str::FromStr;

    pub trait DurationExt {
        fn format_colon_separated(&self) -> String;
    }

    impl DurationExt for Duration {
        fn format_colon_separated(&self) -> String {
            let total_seconds = self.as_secs();
            let hours = total_seconds / 3600;
            let minutes = (total_seconds % 3600) / 60;
            let seconds = total_seconds % 60;
            let millis = self.subsec_millis();

            format!("{:02}:{:02}:{:02}:{:03}", hours, minutes, seconds, millis)
        }
    }


    #[derive(Debug, PartialEq, Eq)]
    enum TimeUnit {
        Hours,
        Minutes,
        Seconds,
        Milliseconds,
    }

    impl TimeUnit {
        fn parse(s: &str) -> Option<Self> {
            match s.to_lowercase().as_str() {
                "h" | "hr" | "hrs" | "hours" => Some(Self::Hours),
                "m" | "min" | "mins" | "minutes" => Some(Self::Minutes),
                "s" | "sec" | "secs" | "seconds" => Some(Self::Seconds),
                "ms" | "milli" | "millis" | "milliseconds" => Some(Self::Milliseconds),
                "" => Some(Self::Seconds),
                _ => None,
            }
        }

        fn to_duration(&self, count: u64) -> Duration {
            match self {
                Self::Hours => Duration::from_secs(count * 3600),
                Self::Minutes => Duration::from_secs(count * 60),
                Self::Seconds => Duration::from_secs(count),
                Self::Milliseconds => Duration::from_millis(count),
            }
        }
    }

    fn parse_duration_component(component: &str) -> Option<Duration> {
        let split_point = component.find(|c: char| !c.is_digit(10)).unwrap_or(component.len());
        let (count_str, unit_str) = component.split_at(split_point);
        let count = u64::from_str(count_str).ok()?;
        let unit = TimeUnit::parse(unit_str)?;
        Some(unit.to_duration(count))
    }

    pub fn parse_duration_from_components(components: &[String]) -> Option<Duration> {
        components
            .iter()
            .map(|c| parse_duration_component(c))
            .sum()
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn test_parse_duration() {
            let cases = vec![
                (vec!["1".to_string()], Some(Duration::from_secs(1))),
                (vec!["12".to_string()], Some(Duration::from_secs(12))),
                (vec!["500ms".to_string()], Some(Duration::from_millis(500))),
                (vec!["5s".to_string()], Some(Duration::from_secs(5))),
                (vec!["5sec".to_string()], Some(Duration::from_secs(5))),
                (vec!["5secs".to_string()], Some(Duration::from_secs(5))),
                (vec!["5m".to_string()], Some(Duration::from_secs(5 * 60))),
                (vec!["5min".to_string()], Some(Duration::from_secs(5 * 60))),
                (vec!["5mins".to_string()], Some(Duration::from_secs(5 * 60))),
                (vec!["1m".to_string(), "30".to_string()], Some(Duration::from_secs(90))),
                (vec!["1m".to_string(), "30s".to_string()], Some(Duration::from_secs(90))),
                (vec!["1min".to_string(), "30s".to_string()], Some(Duration::from_secs(90))),
                (vec!["1m".to_string(), "30sec".to_string()], Some(Duration::from_secs(90))),
                (vec!["2h".to_string(), "15m".to_string()], Some(Duration::from_secs(2 * 3600 + 15 * 60))),
                (vec!["2hrs".to_string(), "15mins".to_string()], Some(Duration::from_secs(2 * 3600 + 15 * 60))),
            ];

            for (input, expected) in cases {
                let actual = parse_duration_from_components(&input);
                assert_eq!(actual, expected, "Failed for input: {:?}", input);
            }
        }
    }
}
