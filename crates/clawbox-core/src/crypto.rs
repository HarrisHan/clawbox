//! Cryptographic operations for ClawBox
//!
//! Uses:
//! - Argon2id for key derivation
//! - AES-256-GCM for encryption

use crate::{Error, Result};
use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use argon2::Argon2;
use rand::RngCore;
use zeroize::Zeroize;

/// Argon2id parameters
const ARGON2_MEMORY_KB: u32 = 65536; // 64 MB
const ARGON2_ITERATIONS: u32 = 3;
const ARGON2_PARALLELISM: u32 = 4;

/// Key sizes
const SALT_LEN: usize = 32;
const KEY_LEN: usize = 32; // 256 bits
const NONCE_LEN: usize = 12; // 96 bits for GCM

/// Derived key with zeroize on drop
#[derive(Zeroize)]
#[zeroize(drop)]
pub struct DerivedKey {
    bytes: [u8; KEY_LEN],
}

impl DerivedKey {
    /// Get key bytes (internal use only)
    pub(crate) fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }
    
    /// Create from raw bytes (for sync)
    pub fn from_bytes(bytes: Vec<u8>) -> Self {
        let mut key_bytes = [0u8; KEY_LEN];
        let len = bytes.len().min(KEY_LEN);
        key_bytes[..len].copy_from_slice(&bytes[..len]);
        Self { bytes: key_bytes }
    }
    
    /// Export bytes (for sync)
    pub fn to_bytes(&self) -> Vec<u8> {
        self.bytes.to_vec()
    }
}

/// Encrypted data container
pub struct EncryptedData {
    pub nonce: Vec<u8>,
    pub ciphertext: Vec<u8>,
}

/// Generate random salt
pub fn generate_salt() -> Vec<u8> {
    let mut salt = vec![0u8; SALT_LEN];
    rand::thread_rng().fill_bytes(&mut salt);
    salt
}

/// Derive encryption key from password using Argon2id
pub fn derive_key(password: &str, salt: &[u8]) -> Result<DerivedKey> {
    let argon2 = Argon2::new(
        argon2::Algorithm::Argon2id,
        argon2::Version::V0x13,
        argon2::Params::new(
            ARGON2_MEMORY_KB,
            ARGON2_ITERATIONS,
            ARGON2_PARALLELISM,
            Some(KEY_LEN),
        )
        .map_err(|e| Error::Encryption(e.to_string()))?,
    );

    let mut key_bytes = [0u8; KEY_LEN];
    argon2
        .hash_password_into(password.as_bytes(), salt, &mut key_bytes)
        .map_err(|e| Error::Encryption(e.to_string()))?;

    Ok(DerivedKey { bytes: key_bytes })
}

/// Encrypt data using AES-256-GCM
pub fn encrypt(plaintext: &[u8], key: &DerivedKey) -> Result<EncryptedData> {
    let cipher = Aes256Gcm::new_from_slice(key.as_bytes())
        .map_err(|e| Error::Encryption(e.to_string()))?;

    let mut nonce_bytes = [0u8; NONCE_LEN];
    rand::thread_rng().fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    let ciphertext = cipher
        .encrypt(nonce, plaintext)
        .map_err(|e| Error::Encryption(e.to_string()))?;

    Ok(EncryptedData {
        nonce: nonce_bytes.to_vec(),
        ciphertext,
    })
}

/// Decrypt data using AES-256-GCM
pub fn decrypt(encrypted: &EncryptedData, key: &DerivedKey) -> Result<Vec<u8>> {
    let cipher = Aes256Gcm::new_from_slice(key.as_bytes())
        .map_err(|e| Error::Decryption(e.to_string()))?;

    let nonce = Nonce::from_slice(&encrypted.nonce);

    let plaintext = cipher
        .decrypt(nonce, encrypted.ciphertext.as_ref())
        .map_err(|e| Error::Decryption(e.to_string()))?;

    Ok(plaintext)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encrypt_decrypt() {
        let password = "test-password";
        let salt = generate_salt();
        let key = derive_key(password, &salt).unwrap();

        let plaintext = b"Hello, World!";
        let encrypted = encrypt(plaintext, &key).unwrap();
        let decrypted = decrypt(&encrypted, &key).unwrap();

        assert_eq!(plaintext.as_slice(), decrypted.as_slice());
    }

    #[test]
    fn test_wrong_password() {
        let salt = generate_salt();
        let key1 = derive_key("password1", &salt).unwrap();
        let key2 = derive_key("password2", &salt).unwrap();

        let plaintext = b"Secret data";
        let encrypted = encrypt(plaintext, &key1).unwrap();

        // Decryption with wrong key should fail
        assert!(decrypt(&encrypted, &key2).is_err());
    }
}
