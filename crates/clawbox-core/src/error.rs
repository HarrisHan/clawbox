//! Error types for ClawBox

use thiserror::Error;

/// Result type alias
pub type Result<T> = std::result::Result<T, Error>;

/// ClawBox error types
#[derive(Error, Debug)]
pub enum Error {
    #[error("Vault is locked")]
    VaultLocked,

    #[error("Vault not found at {path}")]
    VaultNotFound { path: String },

    #[error("Secret not found: {path}")]
    SecretNotFound { path: String },

    #[error("Invalid master password")]
    InvalidPassword,

    #[error("Access denied: {reason}")]
    AccessDenied { reason: String },

    #[error("Approval timeout")]
    ApprovalTimeout,

    #[error("Encryption error: {0}")]
    Encryption(String),

    #[error("Decryption error: {0}")]
    Decryption(String),

    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("{0}")]
    Other(String),
}
