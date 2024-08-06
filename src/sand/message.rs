use serde::{Deserialize, Serialize};

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Command {
    List,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ListResponse {
    Ok { timers: Vec<String> },
}

impl ListResponse {
    pub fn ok(timers: Vec<String>) -> Self {
        ListResponse::Ok { timers }
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn serde_message() {
        let cmd = Command::List;
        let serialized = serde_json::to_string(&cmd).unwrap();
        assert_eq!("\"list\"", serialized);

        let deserialized: Command = serde_json::from_str(&serialized).unwrap();
        assert_eq!(Command::List, deserialized);
    }

    #[test]
    fn serde_list_response() {
        let response = ListResponse::ok(vec![]);
        let serialized = serde_json::to_string(&response).unwrap();
        assert_eq!("{\"ok\":{\"timers\":[]}}", serialized);

        let deserialized: ListResponse = serde_json::from_str(&serialized).unwrap();
        assert_eq!(ListResponse::ok(vec![]), deserialized);
    }
}