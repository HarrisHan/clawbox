//! ClawBox FFI bindings
//!
//! C-compatible API for Swift/Objective-C integration

use clawbox_core::ClawBox;
use libc::{c_char, c_int};
use std::ffi::{CStr, CString};
use std::ptr;

/// Opaque handle to ClawBox vault
pub struct ClawBoxHandle {
    vault: ClawBox,
}

/// Error codes
pub const CLAWBOX_OK: c_int = 0;
pub const CLAWBOX_ERR_VAULT_LOCKED: c_int = 1;
pub const CLAWBOX_ERR_INVALID_PASSWORD: c_int = 2;
pub const CLAWBOX_ERR_NOT_FOUND: c_int = 3;
pub const CLAWBOX_ERR_IO: c_int = 4;
pub const CLAWBOX_ERR_UNKNOWN: c_int = -1;

/// Open a vault at the given path
///
/// # Safety
/// `path` must be a valid null-terminated C string
#[no_mangle]
pub unsafe extern "C" fn clawbox_open(path: *const c_char) -> *mut ClawBoxHandle {
    if path.is_null() {
        return ptr::null_mut();
    }

    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };

    match ClawBox::open(path_str) {
        Ok(vault) => Box::into_raw(Box::new(ClawBoxHandle { vault })),
        Err(_) => ptr::null_mut(),
    }
}

/// Close and free the vault handle
///
/// # Safety
/// `handle` must be a valid pointer returned by `clawbox_open`
#[no_mangle]
pub unsafe extern "C" fn clawbox_close(handle: *mut ClawBoxHandle) {
    if !handle.is_null() {
        drop(Box::from_raw(handle));
    }
}

/// Initialize a new vault with master password
///
/// # Safety
/// `handle` and `password` must be valid pointers
#[no_mangle]
pub unsafe extern "C" fn clawbox_init(
    handle: *mut ClawBoxHandle,
    password: *const c_char,
) -> c_int {
    if handle.is_null() || password.is_null() {
        return CLAWBOX_ERR_UNKNOWN;
    }

    let handle = &mut *handle;
    let password_str = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return CLAWBOX_ERR_UNKNOWN,
    };

    match handle.vault.init(password_str) {
        Ok(_) => CLAWBOX_OK,
        Err(_) => CLAWBOX_ERR_IO,
    }
}

/// Unlock the vault
///
/// # Safety
/// `handle` and `password` must be valid pointers
#[no_mangle]
pub unsafe extern "C" fn clawbox_unlock(
    handle: *mut ClawBoxHandle,
    password: *const c_char,
) -> c_int {
    if handle.is_null() || password.is_null() {
        return CLAWBOX_ERR_UNKNOWN;
    }

    let handle = &mut *handle;
    let password_str = match CStr::from_ptr(password).to_str() {
        Ok(s) => s,
        Err(_) => return CLAWBOX_ERR_UNKNOWN,
    };

    match handle.vault.unlock(password_str) {
        Ok(_) => CLAWBOX_OK,
        Err(clawbox_core::Error::InvalidPassword) => CLAWBOX_ERR_INVALID_PASSWORD,
        Err(_) => CLAWBOX_ERR_UNKNOWN,
    }
}

/// Lock the vault
///
/// # Safety
/// `handle` must be a valid pointer
#[no_mangle]
pub unsafe extern "C" fn clawbox_lock(handle: *mut ClawBoxHandle) {
    if !handle.is_null() {
        let handle = &mut *handle;
        handle.vault.lock();
    }
}

/// Check if vault is unlocked
///
/// # Safety
/// `handle` must be a valid pointer
#[no_mangle]
pub unsafe extern "C" fn clawbox_is_unlocked(handle: *const ClawBoxHandle) -> c_int {
    if handle.is_null() {
        return 0;
    }

    let handle = &*handle;
    if handle.vault.is_unlocked() { 1 } else { 0 }
}

/// Get a secret value
///
/// # Safety
/// `handle`, `path`, and `out_value` must be valid pointers
#[no_mangle]
pub unsafe extern "C" fn clawbox_get(
    handle: *mut ClawBoxHandle,
    path: *const c_char,
    out_value: *mut *mut c_char,
) -> c_int {
    if handle.is_null() || path.is_null() || out_value.is_null() {
        return CLAWBOX_ERR_UNKNOWN;
    }

    let handle = &*handle;
    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return CLAWBOX_ERR_UNKNOWN,
    };

    match handle.vault.get(path_str) {
        Ok(Some(value)) => {
            match CString::new(value) {
                Ok(c_str) => {
                    *out_value = c_str.into_raw();
                    CLAWBOX_OK
                }
                Err(_) => CLAWBOX_ERR_UNKNOWN,
            }
        }
        Ok(None) => CLAWBOX_ERR_NOT_FOUND,
        Err(clawbox_core::Error::VaultLocked) => CLAWBOX_ERR_VAULT_LOCKED,
        Err(_) => CLAWBOX_ERR_UNKNOWN,
    }
}

/// Free a string returned by clawbox_get
///
/// # Safety
/// `s` must be a valid pointer returned by clawbox_get
#[no_mangle]
pub unsafe extern "C" fn clawbox_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

/// Set a secret value
///
/// # Safety
/// `handle`, `path`, and `value` must be valid pointers
#[no_mangle]
pub unsafe extern "C" fn clawbox_set(
    handle: *mut ClawBoxHandle,
    path: *const c_char,
    value: *const c_char,
    access_level: c_int,
) -> c_int {
    if handle.is_null() || path.is_null() || value.is_null() {
        return CLAWBOX_ERR_UNKNOWN;
    }

    let handle = &mut *handle;
    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return CLAWBOX_ERR_UNKNOWN,
    };
    let value_str = match CStr::from_ptr(value).to_str() {
        Ok(s) => s,
        Err(_) => return CLAWBOX_ERR_UNKNOWN,
    };

    let access = match access_level {
        0 => clawbox_core::AccessLevel::Public,
        1 => clawbox_core::AccessLevel::Normal,
        2 => clawbox_core::AccessLevel::Sensitive,
        3 => clawbox_core::AccessLevel::Critical,
        _ => clawbox_core::AccessLevel::Normal,
    };

    let opts = clawbox_core::SetOptions {
        access,
        ..Default::default()
    };

    match handle.vault.set(path_str, value_str, opts) {
        Ok(_) => CLAWBOX_OK,
        Err(clawbox_core::Error::VaultLocked) => CLAWBOX_ERR_VAULT_LOCKED,
        Err(_) => CLAWBOX_ERR_UNKNOWN,
    }
}

/// Delete a secret
///
/// # Safety
/// `handle` and `path` must be valid pointers
#[no_mangle]
pub unsafe extern "C" fn clawbox_delete(
    handle: *mut ClawBoxHandle,
    path: *const c_char,
) -> c_int {
    if handle.is_null() || path.is_null() {
        return CLAWBOX_ERR_UNKNOWN;
    }

    let handle = &mut *handle;
    let path_str = match CStr::from_ptr(path).to_str() {
        Ok(s) => s,
        Err(_) => return CLAWBOX_ERR_UNKNOWN,
    };

    match handle.vault.delete(path_str) {
        Ok(true) => CLAWBOX_OK,
        Ok(false) => CLAWBOX_ERR_NOT_FOUND,
        Err(clawbox_core::Error::VaultLocked) => CLAWBOX_ERR_VAULT_LOCKED,
        Err(_) => CLAWBOX_ERR_UNKNOWN,
    }
}
