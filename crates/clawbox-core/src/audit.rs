//! Audit logging for ClawBox
//!
//! Provides tamper-evident logging of all vault operations.

use crate::{Actor, Result};
use chrono::{DateTime, Utc};
use rusqlite::{Connection, params};
use serde::{Deserialize, Serialize};
use sha2::{Sha256, Digest};

/// Audit action types
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum Action {
    Read,
    Write,
    Delete,
    Export,
    Unlock,
    Lock,
    Init,
}

impl Action {
    pub fn as_str(&self) -> &'static str {
        match self {
            Action::Read => "read",
            Action::Write => "write",
            Action::Delete => "delete",
            Action::Export => "export",
            Action::Unlock => "unlock",
            Action::Lock => "lock",
            Action::Init => "init",
        }
    }
    
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "read" => Some(Action::Read),
            "write" => Some(Action::Write),
            "delete" => Some(Action::Delete),
            "export" => Some(Action::Export),
            "unlock" => Some(Action::Unlock),
            "lock" => Some(Action::Lock),
            "init" => Some(Action::Init),
            _ => None,
        }
    }
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
    pub hash: Option<String>,
    pub prev_hash: Option<String>,
}

impl AuditEntry {
    /// Create a new audit entry
    pub fn new(action: Action, key_path: &str, success: bool) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp: Utc::now(),
            actor: ActorInfo::default(),
            action,
            key_path: key_path.to_string(),
            success,
            error_message: None,
            source: Source::CLI { pwd: std::env::current_dir()
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_default() },
            hash: None,
            prev_hash: None,
        }
    }
    
    /// Set error message
    pub fn with_error(mut self, msg: &str) -> Self {
        self.error_message = Some(msg.to_string());
        self
    }
    
    /// Set actor
    pub fn with_actor(mut self, actor: ActorInfo) -> Self {
        self.actor = actor;
        self
    }
    
    /// Compute hash for integrity
    fn compute_hash(&self, prev_hash: Option<&str>) -> String {
        let mut hasher = Sha256::new();
        hasher.update(self.id.as_bytes());
        hasher.update(self.timestamp.to_rfc3339().as_bytes());
        hasher.update(self.actor.actor_type.as_bytes());
        hasher.update(self.action.as_str().as_bytes());
        hasher.update(self.key_path.as_bytes());
        hasher.update(if self.success { b"1" } else { b"0" });
        if let Some(prev) = prev_hash {
            hasher.update(prev.as_bytes());
        }
        format!("{:x}", hasher.finalize())
    }
}

/// Serializable actor info
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
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

impl ActorInfo {
    pub fn human() -> Self {
        Self {
            actor_type: "human".to_string(),
            identifier: whoami::username(),
        }
    }
    
    pub fn ai(agent: &str) -> Self {
        Self {
            actor_type: "ai".to_string(),
            identifier: agent.to_string(),
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

/// Audit logger with SQLite backend
pub struct AuditLogger<'a> {
    conn: &'a Connection,
}

impl<'a> AuditLogger<'a> {
    /// Create a new audit logger
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }
    
    /// Get the last hash for chain integrity
    fn get_last_hash(&self) -> Result<Option<String>> {
        let mut stmt = self.conn.prepare(
            "SELECT hash FROM audit_log ORDER BY timestamp DESC LIMIT 1"
        )?;
        
        let result = stmt.query_row([], |row| row.get(0));
        match result {
            Ok(hash) => Ok(Some(hash)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    /// Log an audit entry
    pub fn log(&self, mut entry: AuditEntry) -> Result<()> {
        // Get previous hash for chain
        let prev_hash = self.get_last_hash()?;
        entry.prev_hash = prev_hash.clone();
        entry.hash = Some(entry.compute_hash(prev_hash.as_deref()));
        
        let actor_json = serde_json::to_string(&entry.actor)?;
        let source_json = serde_json::to_string(&entry.source)?;
        
        self.conn.execute(
            r#"INSERT INTO audit_log 
               (id, timestamp, actor, action, key_path, success, error_message, source, hash, prev_hash)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"#,
            params![
                entry.id,
                entry.timestamp.timestamp(),
                actor_json,
                entry.action.as_str(),
                entry.key_path,
                entry.success,
                entry.error_message,
                source_json,
                entry.hash,
                entry.prev_hash,
            ],
        )?;
        
        Ok(())
    }

    /// Query audit log
    pub fn query(&self, filter: &AuditFilter) -> Result<Vec<AuditEntry>> {
        let mut sql = String::from(
            "SELECT id, timestamp, actor, action, key_path, success, error_message, source, hash, prev_hash 
             FROM audit_log WHERE 1=1"
        );
        
        if filter.key_path.is_some() {
            sql.push_str(" AND key_path LIKE ?");
        }
        if filter.since.is_some() {
            sql.push_str(" AND timestamp >= ?");
        }
        if filter.until.is_some() {
            sql.push_str(" AND timestamp <= ?");
        }
        if filter.actor_type.is_some() {
            sql.push_str(" AND actor LIKE ?");
        }
        if filter.action.is_some() {
            sql.push_str(" AND action = ?");
        }
        
        sql.push_str(" ORDER BY timestamp DESC");
        
        if let Some(limit) = filter.limit {
            sql.push_str(&format!(" LIMIT {}", limit));
        }
        
        let mut stmt = self.conn.prepare(&sql)?;
        
        // Build params dynamically
        let mut params: Vec<Box<dyn rusqlite::ToSql>> = vec![];
        
        if let Some(ref path) = filter.key_path {
            params.push(Box::new(format!("%{}%", path)));
        }
        if let Some(ref since) = filter.since {
            params.push(Box::new(since.timestamp()));
        }
        if let Some(ref until) = filter.until {
            params.push(Box::new(until.timestamp()));
        }
        if let Some(ref actor) = filter.actor_type {
            params.push(Box::new(format!("%\"actor_type\":\"{}%", actor)));
        }
        if let Some(ref action) = filter.action {
            params.push(Box::new(action.as_str().to_string()));
        }
        
        let params_refs: Vec<&dyn rusqlite::ToSql> = params.iter().map(|p| p.as_ref()).collect();
        
        let mut rows = stmt.query(params_refs.as_slice())?;
        let mut entries = vec![];
        
        while let Some(row) = rows.next()? {
            let ts: i64 = row.get(1)?;
            let actor_json: String = row.get(2)?;
            let action_str: String = row.get(3)?;
            let source_json: String = row.get(7)?;
            
            entries.push(AuditEntry {
                id: row.get(0)?,
                timestamp: DateTime::from_timestamp(ts, 0).unwrap_or_default().into(),
                actor: serde_json::from_str(&actor_json).unwrap_or_default(),
                action: Action::from_str(&action_str).unwrap_or(Action::Read),
                key_path: row.get(4)?,
                success: row.get(5)?,
                error_message: row.get(6)?,
                source: serde_json::from_str(&source_json).unwrap_or(Source::CLI { pwd: String::new() }),
                hash: row.get(8)?,
                prev_hash: row.get(9)?,
            });
        }
        
        Ok(entries)
    }
    
    /// Verify audit log integrity
    pub fn verify_integrity(&self) -> Result<bool> {
        let entries = self.query(&AuditFilter::default())?;
        
        // Entries are in DESC order, reverse for verification
        let entries: Vec<_> = entries.into_iter().rev().collect();
        
        let mut prev_hash: Option<String> = None;
        for entry in entries {
            let computed = entry.compute_hash(prev_hash.as_deref());
            if entry.hash.as_ref() != Some(&computed) {
                return Ok(false);
            }
            prev_hash = entry.hash;
        }
        
        Ok(true)
    }
}
