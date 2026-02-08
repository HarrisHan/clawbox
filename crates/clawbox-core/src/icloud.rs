//! iCloud Sync for ClawBox
//!
//! Provides automatic sync across macOS/iOS devices via iCloud Drive.

#![allow(unexpected_cfgs)]

use crate::{crypto, Result, Error};
use std::path::{Path, PathBuf};
use std::fs;
use std::time::{SystemTime, UNIX_EPOCH};

/// iCloud container identifier
const ICLOUD_CONTAINER: &str = "iCloud~com~harrishan~ClawBox";

/// Sync file names
const VAULT_FILE: &str = "vault.encrypted";
const META_FILE: &str = "vault.meta";
#[allow(dead_code)]
const LOCK_FILE: &str = "sync.lock";

/// Sync metadata
#[derive(Debug, Clone)]
pub struct SyncMeta {
    pub version: u64,
    pub timestamp: u64,
    pub device_id: String,
}

impl SyncMeta {
    pub fn new(version: u64) -> Self {
        Self {
            version,
            timestamp: SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs(),
            device_id: get_device_id(),
        }
    }

    pub fn from_file(path: &Path) -> Result<Self> {
        let content = fs::read_to_string(path)?;
        let mut lines = content.lines();
        
        Ok(Self {
            version: lines.next()
                .and_then(|s| s.parse().ok())
                .unwrap_or(0),
            timestamp: lines.next()
                .and_then(|s| s.parse().ok())
                .unwrap_or(0),
            device_id: lines.next()
                .unwrap_or("")
                .to_string(),
        })
    }

    pub fn to_file(&self, path: &Path) -> Result<()> {
        let content = format!("{}\n{}\n{}", self.version, self.timestamp, self.device_id);
        fs::write(path, content)?;
        Ok(())
    }
}

/// Get unique device identifier
fn get_device_id() -> String {
    // Use hostname as device ID
    hostname::get()
        .map(|h| h.to_string_lossy().to_string())
        .unwrap_or_else(|_| "unknown".to_string())
}

/// iCloud sync manager
pub struct ICloudSync {
    icloud_path: Option<PathBuf>,
    local_vault_path: PathBuf,
    encryption_key: Option<Vec<u8>>,
}

impl ICloudSync {
    /// Create new iCloud sync manager
    pub fn new(local_vault_path: PathBuf) -> Self {
        Self {
            icloud_path: Self::find_icloud_path(),
            local_vault_path,
            encryption_key: None,
        }
    }

    /// Find iCloud Drive path
    fn find_icloud_path() -> Option<PathBuf> {
        let home = dirs::home_dir()?;
        let icloud_base = home.join("Library/Mobile Documents");
        let container_path = icloud_base.join(ICLOUD_CONTAINER).join("Documents");
        
        if icloud_base.exists() {
            // Create container if it doesn't exist
            if !container_path.exists() {
                fs::create_dir_all(&container_path).ok()?;
            }
            Some(container_path)
        } else {
            None
        }
    }

    /// Check if iCloud is available
    pub fn is_available(&self) -> bool {
        self.icloud_path.is_some()
    }

    /// Get iCloud path
    pub fn icloud_path(&self) -> Option<&Path> {
        self.icloud_path.as_deref()
    }

    /// Set encryption key for sync
    pub fn set_key(&mut self, key: Vec<u8>) {
        self.encryption_key = Some(key);
    }

    /// Get local vault version
    pub fn local_version(&self) -> Result<u64> {
        let meta_path = self.local_vault_path.join("sync.meta");
        if meta_path.exists() {
            let meta = SyncMeta::from_file(&meta_path)?;
            Ok(meta.version)
        } else {
            Ok(0)
        }
    }

    /// Get remote (iCloud) vault version
    pub fn remote_version(&self) -> Result<u64> {
        let icloud_path = self.icloud_path.as_ref()
            .ok_or_else(|| Error::Other("iCloud not available".to_string()))?;
        
        let meta_path = icloud_path.join(META_FILE);
        if meta_path.exists() {
            let meta = SyncMeta::from_file(&meta_path)?;
            Ok(meta.version)
        } else {
            Ok(0)
        }
    }

    /// Check if remote has newer version
    pub fn needs_pull(&self) -> Result<bool> {
        let local = self.local_version()?;
        let remote = self.remote_version()?;
        Ok(remote > local)
    }

    /// Check if local has newer version
    pub fn needs_push(&self) -> Result<bool> {
        let local = self.local_version()?;
        let remote = self.remote_version()?;
        Ok(local > remote)
    }

    /// Push local vault to iCloud
    pub fn push(&self) -> Result<()> {
        let icloud_path = self.icloud_path.as_ref()
            .ok_or_else(|| Error::Other("iCloud not available".to_string()))?;

        let key = self.encryption_key.as_ref()
            .ok_or_else(|| Error::Other("Encryption key not set".to_string()))?;

        // Read local vault
        let vault_db = self.local_vault_path.join("vault.db");
        let vault_data = fs::read(&vault_db)?;

        // Encrypt vault data
        let encrypted = crypto::encrypt(&vault_data, &crypto::DerivedKey::from_bytes(key.clone()))?;
        
        // Combine nonce + ciphertext
        let mut sync_data = encrypted.nonce;
        sync_data.extend(encrypted.ciphertext);

        // Write to iCloud
        fs::write(icloud_path.join(VAULT_FILE), sync_data)?;

        // Update meta
        let local_version = self.local_version()? + 1;
        let meta = SyncMeta::new(local_version);
        meta.to_file(&icloud_path.join(META_FILE))?;
        meta.to_file(&self.local_vault_path.join("sync.meta"))?;

        Ok(())
    }

    /// Pull vault from iCloud
    pub fn pull(&self) -> Result<()> {
        let icloud_path = self.icloud_path.as_ref()
            .ok_or_else(|| Error::Other("iCloud not available".to_string()))?;

        let key = self.encryption_key.as_ref()
            .ok_or_else(|| Error::Other("Encryption key not set".to_string()))?;

        // Read encrypted vault from iCloud
        let vault_file = icloud_path.join(VAULT_FILE);
        if !vault_file.exists() {
            return Err(Error::Other("No remote vault found".to_string()));
        }

        let sync_data = fs::read(&vault_file)?;
        
        if sync_data.len() < 12 {
            return Err(Error::Other("Invalid sync data".to_string()));
        }

        // Decrypt
        let nonce = sync_data[..12].to_vec();
        let ciphertext = sync_data[12..].to_vec();
        
        let encrypted = crypto::EncryptedData { nonce, ciphertext };
        let vault_data = crypto::decrypt(&encrypted, &crypto::DerivedKey::from_bytes(key.clone()))?;

        // Backup local vault
        let vault_db = self.local_vault_path.join("vault.db");
        if vault_db.exists() {
            let backup = self.local_vault_path.join("vault.db.backup");
            fs::copy(&vault_db, &backup)?;
        }

        // Write decrypted vault
        fs::write(&vault_db, vault_data)?;

        // Update local meta
        let remote_meta = SyncMeta::from_file(&icloud_path.join(META_FILE))?;
        remote_meta.to_file(&self.local_vault_path.join("sync.meta"))?;

        Ok(())
    }

    /// Auto-sync (pull if remote newer, push if local newer)
    pub fn sync(&self) -> Result<SyncResult> {
        if !self.is_available() {
            return Ok(SyncResult::Unavailable);
        }

        let local = self.local_version()?;
        let remote = self.remote_version()?;

        if remote > local {
            self.pull()?;
            Ok(SyncResult::Pulled)
        } else if local > remote {
            self.push()?;
            Ok(SyncResult::Pushed)
        } else {
            Ok(SyncResult::UpToDate)
        }
    }

    /// Watch for iCloud changes (returns when change detected)
    #[cfg(feature = "watch")]
    pub fn watch(&self) -> Result<()> {
        use notify::{Watcher, RecursiveMode, watcher};
        use std::sync::mpsc::channel;
        use std::time::Duration;

        let icloud_path = self.icloud_path.as_ref()
            .ok_or_else(|| Error::Other("iCloud not available".to_string()))?;

        let (tx, rx) = channel();
        let mut watcher = watcher(tx, Duration::from_secs(2))?;
        
        watcher.watch(icloud_path, RecursiveMode::NonRecursive)?;

        // Wait for change
        rx.recv().map_err(|e| Error::Other(e.to_string()))?;
        
        Ok(())
    }
}

/// Sync result
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SyncResult {
    Pulled,
    Pushed,
    UpToDate,
    Unavailable,
}

impl std::fmt::Display for SyncResult {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SyncResult::Pulled => write!(f, "Pulled from iCloud"),
            SyncResult::Pushed => write!(f, "Pushed to iCloud"),
            SyncResult::UpToDate => write!(f, "Already up to date"),
            SyncResult::Unavailable => write!(f, "iCloud not available"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_device_id() {
        let id = get_device_id();
        assert!(!id.is_empty());
    }
}
