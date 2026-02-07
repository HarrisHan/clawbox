//! Storage engine for ClawBox
//!
//! Uses SQLite for persistent storage

use crate::{AccessLevel, Result, SecretInfo};
use rusqlite::Connection;

/// Initialize database schema
pub fn init_schema(conn: &Connection) -> Result<()> {
    conn.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS vault_meta (
            key TEXT PRIMARY KEY,
            value BLOB NOT NULL
        );

        CREATE TABLE IF NOT EXISTS secrets (
            id TEXT PRIMARY KEY,
            path TEXT UNIQUE NOT NULL,
            encrypted_value BLOB NOT NULL,
            access_level INTEGER NOT NULL DEFAULT 1,
            tags TEXT,
            note TEXT,
            ttl_expires_at INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            created_by TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_secrets_path ON secrets(path);
        CREATE INDEX IF NOT EXISTS idx_secrets_ttl ON secrets(ttl_expires_at);

        CREATE TABLE IF NOT EXISTS audit_log (
            id TEXT PRIMARY KEY,
            timestamp INTEGER NOT NULL,
            actor TEXT NOT NULL,
            action TEXT NOT NULL,
            key_path TEXT NOT NULL,
            success INTEGER NOT NULL,
            error_message TEXT,
            source TEXT NOT NULL,
            prev_hash TEXT,
            metadata TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);
        CREATE INDEX IF NOT EXISTS idx_audit_key_path ON audit_log(key_path);
        "#,
    )?;

    Ok(())
}

/// Secret store trait
pub trait SecretStore {
    fn get(&self, path: &str) -> Result<Option<Vec<u8>>>;
    fn set(&mut self, path: &str, value: &[u8], info: &SecretInfo) -> Result<()>;
    fn delete(&mut self, path: &str) -> Result<bool>;
    fn list(&self, pattern: Option<&str>) -> Result<Vec<SecretInfo>>;
}

/// SQLite-based secret store
pub struct SqliteStore {
    conn: Connection,
}

impl SqliteStore {
    /// Open or create a store at the given path
    pub fn open(path: &std::path::Path) -> Result<Self> {
        let conn = Connection::open(path)?;
        init_schema(&conn)?;
        Ok(Self { conn })
    }

    /// Get vault metadata
    pub fn get_meta(&self, key: &str) -> Result<Option<Vec<u8>>> {
        let mut stmt = self.conn.prepare("SELECT value FROM vault_meta WHERE key = ?")?;
        let result = stmt.query_row([key], |row| row.get(0));
        
        match result {
            Ok(value) => Ok(Some(value)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    /// Set vault metadata
    pub fn set_meta(&mut self, key: &str, value: &[u8]) -> Result<()> {
        self.conn.execute(
            "INSERT OR REPLACE INTO vault_meta (key, value) VALUES (?, ?)",
            rusqlite::params![key, value],
        )?;
        Ok(())
    }
}

impl SecretStore for SqliteStore {
    fn get(&self, path: &str) -> Result<Option<Vec<u8>>> {
        let mut stmt = self
            .conn
            .prepare("SELECT encrypted_value FROM secrets WHERE path = ?")?;
        
        let result = stmt.query_row([path], |row| row.get(0));
        
        match result {
            Ok(value) => Ok(Some(value)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    fn set(&mut self, path: &str, value: &[u8], info: &SecretInfo) -> Result<()> {
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().timestamp();
        let tags_json = serde_json::to_string(&info.tags)?;
        let access_level = info.access as i32;

        self.conn.execute(
            r#"
            INSERT INTO secrets (id, path, encrypted_value, access_level, tags, note, created_at, updated_at, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                encrypted_value = excluded.encrypted_value,
                access_level = excluded.access_level,
                tags = excluded.tags,
                note = excluded.note,
                updated_at = excluded.updated_at
            "#,
            rusqlite::params![
                id,
                path,
                value,
                access_level,
                tags_json,
                info.note,
                now,
                now,
                "human"
            ],
        )?;

        Ok(())
    }

    fn delete(&mut self, path: &str) -> Result<bool> {
        let affected = self
            .conn
            .execute("DELETE FROM secrets WHERE path = ?", [path])?;
        Ok(affected > 0)
    }

    fn list(&self, pattern: Option<&str>) -> Result<Vec<SecretInfo>> {
        let sql = match pattern {
            Some(_) => "SELECT path, access_level, tags, note, created_at, updated_at FROM secrets WHERE path LIKE ?",
            None => "SELECT path, access_level, tags, note, created_at, updated_at FROM secrets",
        };

        let mut stmt = self.conn.prepare(sql)?;
        
        let rows = if let Some(p) = pattern {
            let pattern = p.replace('*', "%");
            stmt.query([pattern])?
        } else {
            stmt.query([])?
        };

        let mut results = Vec::new();
        let mut rows = rows;
        
        while let Some(row) = rows.next()? {
            let access_level: i32 = row.get(1)?;
            let tags_json: String = row.get(2)?;
            let tags: Vec<String> = serde_json::from_str(&tags_json).unwrap_or_default();
            
            results.push(SecretInfo {
                path: row.get(0)?,
                access: match access_level {
                    0 => AccessLevel::Public,
                    1 => AccessLevel::Normal,
                    2 => AccessLevel::Sensitive,
                    3 => AccessLevel::Critical,
                    _ => AccessLevel::Normal,
                },
                tags,
                note: row.get(3)?,
                created_at: chrono::DateTime::from_timestamp(row.get(4)?, 0)
                    .unwrap_or_default()
                    .into(),
                updated_at: chrono::DateTime::from_timestamp(row.get(5)?, 0)
                    .unwrap_or_default()
                    .into(),
            });
        }

        Ok(results)
    }
}
