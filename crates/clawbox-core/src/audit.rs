//! Audit logging for ClawBox

use crate::{Actor, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Audit action types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Action {
    Read,
    Write,
    Delete,
    Export,
    Unlock,
    Lock,
}

/// Audit source
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Source {
    CLI { pwd: String },
    App,
    API,
}

/// Audit log entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    pub id: String,
    pub timestamp: DateTime<Utc>,
    pub actor: ActorInfo,
    pub action: Action,
    pub key_path: String,
    pub success: bool,
    pub error_message: Option<String>,
    pub source: Source,
    pub prev_hash: Option<String>,
    pub metadata: std::collections::HashMap<String, String>,
}

/// Serializable actor info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActorInfo {
    pub actor_type: String,
    pub identifier: String,
}

impl From<&Actor> for ActorInfo {
    fn from(actor: &Actor) -> Self {
        match actor {
            Actor::Human { device } => ActorInfo {
                actor_type: "human".to_string(),
                identifier: device.clone(),
            },
            Actor::AI { agent } => ActorInfo {
                actor_type: "ai".to_string(),
                identifier: agent.clone(),
            },
            Actor::App { name } => ActorInfo {
                actor_type: "app".to_string(),
                identifier: name.clone(),
            },
        }
    }
}

/// Audit filter for queries
#[derive(Debug, Default)]
pub struct AuditFilter {
    pub key_path: Option<String>,
    pub since: Option<DateTime<Utc>>,
    pub until: Option<DateTime<Utc>>,
    pub actor_type: Option<String>,
    pub action: Option<Action>,
    pub limit: Option<usize>,
}

/// Audit logger
pub struct AuditLogger {
    // Will be implemented with storage backend
}

impl AuditLogger {
    /// Create a new audit logger
    pub fn new() -> Self {
        Self {}
    }

    /// Log an audit entry
    pub fn log(&self, entry: AuditEntry) -> Result<()> {
        // TODO: Implement persistent logging
        println!(
            "[AUDIT] {} {} {} on {}",
            entry.timestamp.format("%Y-%m-%d %H:%M:%S"),
            entry.actor.actor_type,
            match entry.action {
                Action::Read => "read",
                Action::Write => "write",
                Action::Delete => "delete",
                Action::Export => "export",
                Action::Unlock => "unlock",
                Action::Lock => "lock",
            },
            entry.key_path
        );
        Ok(())
    }

    /// Query audit log
    pub fn query(&self, _filter: &AuditFilter) -> Result<Vec<AuditEntry>> {
        // TODO: Implement query
        Ok(vec![])
    }
}

impl Default for AuditLogger {
    fn default() -> Self {
        Self::new()
    }
}
