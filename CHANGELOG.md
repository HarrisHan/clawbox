# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure
- Core library with encryption (AES-256-GCM) and key derivation (Argon2id)
- SQLite-based secret storage
- CLI with basic commands (init, set, get, list, delete, lock, unlock)
- FFI bindings for Swift integration
- Comprehensive documentation (PRD, Architecture, Security, CLI Reference)

### Security
- Argon2id with 64MB memory cost for password hashing
- AES-256-GCM authenticated encryption
- Zeroize sensitive data in memory

## [0.1.0] - TBD

### Added
- First MVP release
- Basic vault management
- CLI tool for secret operations
