//! ClawBox Core Library
//!
//! AI-Native Secret Manager - Core functionality
//!
//! # Features
//!
//! - AES-256-GCM encryption
//! - Argon2id key derivation
//! - SQLite storage
//! - Audit logging
//!
//! # Example
//!
//! ```rust,ignore
//! use clawbox_core::ClawBox;
//!
//! let mut vault = ClawBox::open("~/.clawbox")?;
//! vault.unlock("master-password")?;
//!
//! vault.set("github/token", "ghp_xxx", Default::default())?;
//! let token = vault.get("github/token")?;
//! ```

pub mod crypto;
pub mod storage;
pub mod audit;
pub mod vault;
pub mod error;

pub use error::{Error, Result};
pub use vault::ClawBox;

/// Access level for secrets
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum AccessLevel {
    /// Public - AI can access freely
    Public,
    /// Normal - AI needs vault unlocked
    #[default]
    Normal,
    /// Sensitive - AI access requires approval
    Sensitive,
    /// Critical - Human only
    Critical,
}

/// Actor type for audit logging
#[derive(Debug, Clone)]
pub enum Actor {
    Human { device: String },
    AI { agent: String },
    App { name: String },
}

/// Options for setting a secret
#[derive(Debug, Default)]
pub struct SetOptions {
    pub access: AccessLevel,
    pub ttl: Option<std::time::Duration>,
    pub tags: Vec<String>,
    pub note: Option<String>,
}

/// Secret metadata (without value)
#[derive(Debug, Clone)]
pub struct SecretInfo {
    pub path: String,
    pub access: AccessLevel,
    pub tags: Vec<String>,
    pub note: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}
