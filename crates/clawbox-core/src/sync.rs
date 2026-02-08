//! Cloud sync for ClawBox
//!
//! Provides end-to-end encrypted sync using iCloud or custom backends.

use crate::{Result, Error};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Sync state for a vault
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncState {
    pub last_sync: Option<DateTime<Utc>>,
    pub local_version: u64,
    pub remote_version: u64,
    pub sync_enabled: bool,
    pub conflict_count: usize,
}

impl Default for SyncState {
    fn default() -> Self {
        Self {
            last_sync: None,
            local_version: 0,
            remote_version: 0,
            sync_enabled: false,
            conflict_count: 0,
        }
    }
}

/// Sync conflict
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncConflict {
    pub path: String,
    pub local_value: String,
    pub remote_value: String,
    pub local_updated: DateTime<Utc>,
    pub remote_updated: DateTime<Utc>,
}

/// Resolution strategy
#[derive(Debug, Clone, Copy)]
pub enum ConflictResolution {
    KeepLocal,
    KeepRemote,
    KeepBoth,  // Creates path.conflict
}

/// Sync backend trait
pub trait SyncBackend: Send + Sync {
    /// Check if connected
    fn is_connected(&self) -> bool;
    
    /// Get remote version
    fn get_remote_version(&self) -> Result<u64>;
    
    /// Upload encrypted vault
    fn upload(&self, data: &[u8], version: u64) -> Result<()>;
    
    /// Download encrypted vault
    fn download(&self) -> Result<(Vec<u8>, u64)>;
}

/// iCloud sync backend
#[cfg(target_os = "macos")]
pub struct ICloudBackend {
    container_id: String,
    vault_file: String,
}

#[cfg(target_os = "macos")]
impl ICloudBackend {
    pub fn new(container_id: &str) -> Self {
        Self {
            container_id: container_id.to_string(),
            vault_file: "vault.encrypted".to_string(),
        }
    }
    
    fn icloud_path(&self) -> Option<std::path::PathBuf> {
        // ~/Library/Mobile Documents/iCloud~<container_id>/Documents/
        let home = dirs::home_dir()?;
        let container = self.container_id.replace(".", "~");
        Some(home
            .join("Library/Mobile Documents")
            .join(format!("iCloud~{}", container))
            .join("Documents"))
    }
}

#[cfg(target_os = "macos")]
impl SyncBackend for ICloudBackend {
    fn is_connected(&self) -> bool {
        self.icloud_path()
            .map(|p| p.exists())
            .unwrap_or(false)
    }
    
    fn get_remote_version(&self) -> Result<u64> {
        let path = self.icloud_path()
            .ok_or_else(|| Error::Other("iCloud not available".to_string()))?;
        
        let meta_path = path.join("vault.meta");
        if !meta_path.exists() {
            return Ok(0);
        }
        
        let content = std::fs::read_to_string(&meta_path)?;
        let version: u64 = content.trim().parse().unwrap_or(0);
        Ok(version)
    }
    
    fn upload(&self, data: &[u8], version: u64) -> Result<()> {
        let path = self.icloud_path()
            .ok_or_else(|| Error::Other("iCloud not available".to_string()))?;
        
        std::fs::create_dir_all(&path)?;
        std::fs::write(path.join(&self.vault_file), data)?;
        std::fs::write(path.join("vault.meta"), version.to_string())?;
        
        Ok(())
    }
    
    fn download(&self) -> Result<(Vec<u8>, u64)> {
        let path = self.icloud_path()
            .ok_or_else(|| Error::Other("iCloud not available".to_string()))?;
        
        let data = std::fs::read(path.join(&self.vault_file))?;
        let version = self.get_remote_version()?;
        
        Ok((data, version))
    }
}

/// Export format for sync
#[derive(Debug, Serialize, Deserialize)]
pub struct SyncBundle {
    pub version: u64,
    pub timestamp: DateTime<Utc>,
    pub secrets: Vec<SyncSecret>,
    pub audit_hash: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SyncSecret {
    pub path: String,
    pub encrypted_value: Vec<u8>,
    pub nonce: Vec<u8>,
    pub access_level: u8,
    pub tags: Vec<String>,
    pub note: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

/// Sync manager
pub struct SyncManager {
    state: SyncState,
}

impl SyncManager {
    pub fn new() -> Self {
        Self {
            state: SyncState::default(),
        }
    }
    
    /// Get sync state
    pub fn state(&self) -> &SyncState {
        &self.state
    }
    
    /// Enable sync
    pub fn enable(&mut self) {
        self.state.sync_enabled = true;
    }
    
    /// Disable sync
    pub fn disable(&mut self) {
        self.state.sync_enabled = false;
    }
    
    /// Perform sync
    pub fn sync(&mut self, _backend: &dyn SyncBackend) -> Result<()> {
        if !self.state.sync_enabled {
            return Err(Error::Other("Sync not enabled".to_string()));
        }
        
        // TODO: Implement full sync logic
        // 1. Get local and remote versions
        // 2. If remote > local, download and merge
        // 3. If local > remote, upload
        // 4. If equal, no-op
        // 5. Handle conflicts
        
        self.state.last_sync = Some(Utc::now());
        Ok(())
    }
}

impl Default for SyncManager {
    fn default() -> Self {
        Self::new()
    }
}
