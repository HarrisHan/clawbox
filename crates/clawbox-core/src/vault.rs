//! Vault management for ClawBox

use crate::{
    crypto::{self, DerivedKey, EncryptedData},
    error::Error,
    storage::{SecretStore, SqliteStore},
    Result, SecretInfo, SetOptions,
};
use std::path::{Path, PathBuf};

/// Main ClawBox vault
pub struct ClawBox {
    path: PathBuf,
    store: SqliteStore,
    key: Option<DerivedKey>,
}

impl ClawBox {
    /// Open or create a vault at the given path
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref().to_path_buf();
        let db_path = path.join("vault.db");

        // Create directory if needed
        std::fs::create_dir_all(&path)?;

        let store = SqliteStore::open(&db_path)?;

        Ok(Self {
            path,
            store,
            key: None,
        })
    }

    /// Initialize a new vault with master password
    pub fn init(&mut self, password: &str) -> Result<()> {
        // Generate salt
        let salt = crypto::generate_salt();
        self.store.set_meta("salt", &salt)?;

        // Derive key
        let key = crypto::derive_key(password, &salt)?;

        // Create verification token
        let verification = b"clawbox-verification-token";
        let encrypted = crypto::encrypt(verification, &key)?;
        
        // Store verification data
        self.store.set_meta("verification_nonce", &encrypted.nonce)?;
        self.store.set_meta("verification_data", &encrypted.ciphertext)?;

        self.key = Some(key);
        Ok(())
    }

    /// Check if vault is initialized
    pub fn is_initialized(&self) -> Result<bool> {
        Ok(self.store.get_meta("salt")?.is_some())
    }

    /// Unlock vault with master password
    pub fn unlock(&mut self, password: &str) -> Result<()> {
        let salt = self
            .store
            .get_meta("salt")?
            .ok_or(Error::VaultNotFound {
                path: self.path.to_string_lossy().to_string(),
            })?;

        let key = crypto::derive_key(password, &salt)?;

        // Verify password
        let nonce = self.store.get_meta("verification_nonce")?
            .ok_or(Error::InvalidPassword)?;
        let ciphertext = self.store.get_meta("verification_data")?
            .ok_or(Error::InvalidPassword)?;

        let encrypted = EncryptedData { nonce, ciphertext };
        let decrypted = crypto::decrypt(&encrypted, &key)
            .map_err(|_| Error::InvalidPassword)?;

        if decrypted.as_slice() != b"clawbox-verification-token" {
            return Err(Error::InvalidPassword);
        }

        self.key = Some(key);
        Ok(())
    }

    /// Lock the vault
    pub fn lock(&mut self) {
        if let Some(key) = self.key.take() {
            // Key will be zeroized on drop
            drop(key);
        }
    }

    /// Check if vault is unlocked
    pub fn is_unlocked(&self) -> bool {
        self.key.is_some()
    }

    /// Get a secret value
    pub fn get(&self, path: &str) -> Result<Option<String>> {
        let key = self.key.as_ref().ok_or(Error::VaultLocked)?;

        let encrypted_data = self.store.get(path)?;
        
        match encrypted_data {
            Some(data) => {
                // Parse encrypted data (nonce + ciphertext)
                if data.len() < 12 {
                    return Err(Error::Decryption("Invalid data format".to_string()));
                }
                
                let nonce = data[..12].to_vec();
                let ciphertext = data[12..].to_vec();
                
                let encrypted = EncryptedData { nonce, ciphertext };
                let plaintext = crypto::decrypt(&encrypted, key)?;
                
                let value = String::from_utf8(plaintext)
                    .map_err(|e| Error::Decryption(e.to_string()))?;
                
                Ok(Some(value))
            }
            None => Ok(None),
        }
    }

    /// Set a secret value
    pub fn set(&mut self, path: &str, value: &str, opts: SetOptions) -> Result<()> {
        let key = self.key.as_ref().ok_or(Error::VaultLocked)?;

        // Encrypt value
        let encrypted = crypto::encrypt(value.as_bytes(), key)?;
        
        // Combine nonce + ciphertext for storage
        let mut data = encrypted.nonce;
        data.extend(encrypted.ciphertext);

        // Create secret info
        let info = SecretInfo {
            path: path.to_string(),
            access: opts.access,
            tags: opts.tags,
            note: opts.note,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        };

        self.store.set(path, &data, &info)?;
        Ok(())
    }

    /// Delete a secret
    pub fn delete(&mut self, path: &str) -> Result<bool> {
        if !self.is_unlocked() {
            return Err(Error::VaultLocked);
        }
        self.store.delete(path)
    }

    /// List all secrets
    pub fn list(&self, pattern: Option<&str>) -> Result<Vec<SecretInfo>> {
        if !self.is_unlocked() {
            return Err(Error::VaultLocked);
        }
        self.store.list(pattern)
    }

    /// Get vault path
    pub fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for ClawBox {
    fn drop(&mut self) {
        self.lock();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_vault_lifecycle() {
        let temp_dir = TempDir::new().unwrap();
        let vault_path = temp_dir.path().join("test-vault");

        // Create and init vault
        let mut vault = ClawBox::open(&vault_path).unwrap();
        vault.init("test-password").unwrap();

        // Set secret
        vault.set("test/key", "secret-value", Default::default()).unwrap();

        // Lock and unlock
        vault.lock();
        assert!(!vault.is_unlocked());

        vault.unlock("test-password").unwrap();
        assert!(vault.is_unlocked());

        // Get secret
        let value = vault.get("test/key").unwrap();
        assert_eq!(value, Some("secret-value".to_string()));

        // Delete secret
        assert!(vault.delete("test/key").unwrap());
        assert!(vault.get("test/key").unwrap().is_none());
    }

    #[test]
    fn test_wrong_password() {
        let temp_dir = TempDir::new().unwrap();
        let vault_path = temp_dir.path().join("test-vault");

        let mut vault = ClawBox::open(&vault_path).unwrap();
        vault.init("correct-password").unwrap();
        vault.lock();

        let result = vault.unlock("wrong-password");
        assert!(matches!(result, Err(Error::InvalidPassword)));
    }
}
