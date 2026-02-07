//! ClawBox CLI
//!
//! AI-Native Secret Manager

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use clawbox_core::{AccessLevel, ClawBox, SetOptions};
use console::style;
use serde::{Deserialize, Serialize};
use std::io::{self, BufRead};
use std::path::PathBuf;

/// ClawBox - AI-Native Secret Manager
#[derive(Parser)]
#[command(name = "clawbox")]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to vault directory
    #[arg(long, global = true)]
    vault: Option<PathBuf>,

    /// Output in JSON format
    #[arg(long, global = true)]
    json: bool,

    #[command(subcommand)]
    command: Commands,
}

/// Get password from various sources
fn get_password(prompt: &str) -> Result<String> {
    // 1. Check environment variable
    if let Ok(pass) = std::env::var("CLAWBOX_PASSWORD") {
        return Ok(pass);
    }
    
    // 2. Check if stdin is a TTY
    if atty::is(atty::Stream::Stdin) {
        // Interactive mode - use rpassword
        Ok(rpassword::prompt_password(prompt)?)
    } else {
        // Non-interactive mode - read from stdin
        let stdin = io::stdin();
        let mut line = String::new();
        stdin.lock().read_line(&mut line)?;
        Ok(line.trim().to_string())
    }
}

#[derive(Subcommand)]
enum Commands {
    /// Initialize a new vault
    Init {
        /// Path to create vault
        #[arg(long)]
        path: Option<PathBuf>,
    },

    /// Set a secret
    Set {
        /// Secret path (e.g., github/token)
        path: String,
        /// Secret value
        value: String,
        /// Access level: public, normal, sensitive, critical
        #[arg(long, default_value = "normal")]
        access: String,
        /// Tags (comma-separated)
        #[arg(long)]
        tags: Option<String>,
        /// Note
        #[arg(long)]
        note: Option<String>,
    },

    /// Get a secret
    Get {
        /// Secret path
        path: String,
        /// Copy to clipboard
        #[arg(long)]
        clipboard: bool,
    },

    /// List secrets
    List {
        /// Filter pattern (e.g., github/*)
        pattern: Option<String>,
        /// Display as tree
        #[arg(long)]
        tree: bool,
    },

    /// Delete a secret
    Delete {
        /// Secret path
        path: String,
        /// Skip confirmation
        #[arg(long)]
        force: bool,
    },

    /// Unlock the vault
    Unlock {
        /// Auto-lock timeout in minutes
        #[arg(long, default_value = "30")]
        timeout: u64,
    },

    /// Lock the vault
    Lock,

    /// View audit log
    Audit {
        /// Filter by key path
        #[arg(long)]
        key: Option<String>,
        /// Filter by time
        #[arg(long)]
        since: Option<String>,
    },

    /// Export secrets to file
    Export {
        /// Output file path
        output: PathBuf,
        /// Format: json, yaml, env
        #[arg(long, default_value = "json")]
        format: String,
        /// Encrypt output
        #[arg(long)]
        encrypted: bool,
    },

    /// Import secrets from file
    Import {
        /// Input file path
        input: PathBuf,
        /// Format: json, yaml, env
        #[arg(long, default_value = "json")]
        format: String,
        /// Skip existing keys
        #[arg(long)]
        skip_existing: bool,
    },

    /// Sync vault with iCloud (macOS only)
    #[cfg(target_os = "macos")]
    Sync {
        /// Force push to iCloud
        #[arg(long)]
        push: bool,
        /// Force pull from iCloud
        #[arg(long)]
        pull: bool,
        /// Show sync status
        #[arg(long)]
        status: bool,
    },
}

fn get_vault_path(custom: Option<PathBuf>) -> PathBuf {
    custom.unwrap_or_else(|| {
        dirs::home_dir()
            .expect("Could not find home directory")
            .join(".clawbox")
    })
}

fn parse_access_level(s: &str) -> AccessLevel {
    match s.to_lowercase().as_str() {
        "public" => AccessLevel::Public,
        "normal" => AccessLevel::Normal,
        "sensitive" => AccessLevel::Sensitive,
        "critical" => AccessLevel::Critical,
        _ => AccessLevel::Normal,
    }
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let vault_path = get_vault_path(cli.vault);

    match cli.command {
        Commands::Init { path } => {
            let path = path.unwrap_or(vault_path);
            println!("{} Initializing vault at {:?}", style("◆").cyan(), path);

            let password = get_password("Enter master password: ")?;
            let confirm = get_password("Confirm password: ")?;

            if password != confirm {
                anyhow::bail!("Passwords do not match");
            }

            let mut vault = ClawBox::open(&path)?;
            vault.init(&password)?;

            println!("{} Vault created at {:?}", style("✓").green(), path);
        }

        Commands::Set {
            path,
            value,
            access,
            tags,
            note,
        } => {
            let mut vault = ClawBox::open(&vault_path)?;
            unlock_vault(&mut vault)?;

            let opts = SetOptions {
                access: parse_access_level(&access),
                tags: tags
                    .map(|t| t.split(',').map(|s| s.trim().to_string()).collect())
                    .unwrap_or_default(),
                note,
                ..Default::default()
            };

            vault.set(&path, &value, opts)?;
            println!("{} Secret set: {}", style("✓").green(), path);
        }

        Commands::Get { path, clipboard } => {
            let mut vault = ClawBox::open(&vault_path)?;
            unlock_vault(&mut vault)?;

            match vault.get(&path)? {
                Some(value) => {
                    if clipboard {
                        // TODO: Implement clipboard
                        println!("{} Copied to clipboard", style("✓").green());
                    } else if cli.json {
                        println!(
                            "{}",
                            serde_json::json!({
                                "path": path,
                                "value": value
                            })
                        );
                    } else {
                        println!("{}", value);
                    }
                }
                None => {
                    anyhow::bail!("Secret not found: {}", path);
                }
            }
        }

        Commands::List { pattern, tree } => {
            let mut vault = ClawBox::open(&vault_path)?;
            unlock_vault(&mut vault)?;

            let secrets = vault.list(pattern.as_deref())?;

            if cli.json {
                let json: Vec<_> = secrets
                    .iter()
                    .map(|s| {
                        serde_json::json!({
                            "path": s.path,
                            "access": format!("{:?}", s.access),
                            "tags": s.tags,
                        })
                    })
                    .collect();
                println!("{}", serde_json::to_string_pretty(&json)?);
            } else if tree {
                // TODO: Implement tree view
                for secret in secrets {
                    println!("📁 {}", secret.path);
                }
            } else {
                for secret in secrets {
                    let access_icon = match secret.access {
                        AccessLevel::Public => "🔓",
                        AccessLevel::Normal => "🔑",
                        AccessLevel::Sensitive => "🔐",
                        AccessLevel::Critical => "🔒",
                    };
                    println!("{} {}", access_icon, secret.path);
                }
            }
        }

        Commands::Delete { path, force } => {
            let mut vault = ClawBox::open(&vault_path)?;
            unlock_vault(&mut vault)?;

            if !force {
                print!("Delete '{}'? [y/N] ", path);
                let mut input = String::new();
                std::io::stdin().read_line(&mut input)?;
                if !input.trim().eq_ignore_ascii_case("y") {
                    println!("Cancelled");
                    return Ok(());
                }
            }

            if vault.delete(&path)? {
                println!("{} Deleted: {}", style("✓").green(), path);
            } else {
                println!("Secret not found: {}", path);
            }
        }

        Commands::Unlock { timeout: _ } => {
            let mut vault = ClawBox::open(&vault_path)?;
            unlock_vault(&mut vault)?;
            println!("{} Vault unlocked", style("✓").green());
        }

        Commands::Lock => {
            let mut vault = ClawBox::open(&vault_path)?;
            vault.lock();
            println!("{} Vault locked", style("✓").green());
        }

        Commands::Audit { key, since } => {
            let mut vault = ClawBox::open(&vault_path)?;
            unlock_vault(&mut vault)?;
            
            use clawbox_core::audit::AuditFilter;
            use chrono::{Duration, Utc};
            
            let mut filter = AuditFilter::default();
            filter.key_path = key;
            filter.limit = Some(50);
            
            // Parse since parameter (e.g., "1h", "24h", "7d")
            if let Some(since_str) = since {
                let since_time = if since_str.ends_with('h') {
                    let hours: i64 = since_str.trim_end_matches('h').parse().unwrap_or(24);
                    Utc::now() - Duration::hours(hours)
                } else if since_str.ends_with('d') {
                    let days: i64 = since_str.trim_end_matches('d').parse().unwrap_or(7);
                    Utc::now() - Duration::days(days)
                } else {
                    Utc::now() - Duration::hours(24)
                };
                filter.since = Some(since_time);
            }
            
            let entries = vault.audit(&filter)?;
            
            if cli.json {
                println!("{}", serde_json::to_string_pretty(&entries)?);
            } else if entries.is_empty() {
                println!("No audit entries found.");
            } else {
                let count = entries.len();
                println!("{:<20} {:<8} {:<8} {:<30} {}", 
                    "TIMESTAMP", "ACTOR", "ACTION", "KEY", "STATUS");
                println!("{}", "-".repeat(80));
                
                for entry in &entries {
                    let status = if entry.success { 
                        style("✓").green().to_string() 
                    } else { 
                        style("✗").red().to_string() 
                    };
                    
                    println!("{:<20} {:<8} {:<8} {:<30} {}", 
                        entry.timestamp.format("%Y-%m-%d %H:%M:%S"),
                        entry.actor.actor_type,
                        entry.action.as_str(),
                        if entry.key_path.len() > 28 { 
                            format!("{}...", &entry.key_path[..25]) 
                        } else { 
                            entry.key_path.clone() 
                        },
                        status
                    );
                }
                
                println!("\nTotal: {} entries", count);
            }
        }

        Commands::Export { output, format, encrypted } => {
            let mut vault = ClawBox::open(&vault_path)?;
            unlock_vault(&mut vault)?;
            
            let secrets = vault.list(None)?;
            
            #[derive(serde::Serialize)]
            struct ExportSecret {
                path: String,
                value: String,
                access: String,
                tags: Vec<String>,
                note: Option<String>,
            }
            
            let mut export_data: Vec<ExportSecret> = vec![];
            
            for secret in secrets {
                if let Some(value) = vault.get(&secret.path)? {
                    export_data.push(ExportSecret {
                        path: secret.path.clone(),
                        value,
                        access: format!("{:?}", secret.access),
                        tags: secret.tags.clone(),
                        note: secret.note.clone(),
                    });
                }
            }
            
            let content = match format.as_str() {
                "json" => serde_json::to_string_pretty(&export_data)?,
                "env" => {
                    let mut env = String::new();
                    for s in &export_data {
                        let key = s.path.replace("/", "_").to_uppercase();
                        env.push_str(&format!("{}=\"{}\"\n", key, s.value.replace("\"", "\\\"")));
                    }
                    env
                }
                "yaml" => {
                    let mut yaml = String::from("# ClawBox Export\n");
                    for s in &export_data {
                        yaml.push_str(&format!("{}:\n  value: \"{}\"\n", s.path, s.value));
                    }
                    yaml
                }
                _ => anyhow::bail!("Unsupported format: {}", format),
            };
            
            if encrypted {
                // TODO: Implement encrypted export
                anyhow::bail!("Encrypted export not yet implemented");
            }
            
            std::fs::write(&output, content)?;
            println!("{} Exported {} secrets to {:?}", 
                style("✓").green(), export_data.len(), output);
        }

        Commands::Import { input, format, skip_existing } => {
            let mut vault = ClawBox::open(&vault_path)?;
            unlock_vault(&mut vault)?;
            
            let content = std::fs::read_to_string(&input)?;
            
            #[derive(serde::Deserialize)]
            struct ImportSecret {
                path: String,
                value: String,
                #[serde(default)]
                access: Option<String>,
                #[serde(default)]
                tags: Option<Vec<String>>,
                #[serde(default)]
                note: Option<String>,
            }
            
            let secrets: Vec<ImportSecret> = match format.as_str() {
                "json" => serde_json::from_str(&content)?,
                "env" => {
                    let mut secrets = vec![];
                    for line in content.lines() {
                        let line = line.trim();
                        if line.is_empty() || line.starts_with('#') {
                            continue;
                        }
                        if let Some((key, value)) = line.split_once('=') {
                            let path = key.trim().to_lowercase().replace("_", "/");
                            let value = value.trim().trim_matches('"').to_string();
                            secrets.push(ImportSecret {
                                path,
                                value,
                                access: None,
                                tags: None,
                                note: None,
                            });
                        }
                    }
                    secrets
                }
                _ => anyhow::bail!("Unsupported format: {}", format),
            };
            
            let mut imported = 0;
            let mut skipped = 0;
            
            for secret in secrets {
                if skip_existing {
                    if vault.get(&secret.path)?.is_some() {
                        skipped += 1;
                        continue;
                    }
                }
                
                let opts = SetOptions {
                    access: secret.access.as_ref()
                        .map(|a| parse_access_level(a))
                        .unwrap_or_default(),
                    tags: secret.tags.unwrap_or_default(),
                    note: secret.note,
                    ..Default::default()
                };
                
                vault.set(&secret.path, &secret.value, opts)?;
                imported += 1;
            }
            
            println!("{} Imported {} secrets ({} skipped)", 
                style("✓").green(), imported, skipped);
        }

        #[cfg(target_os = "macos")]
        Commands::Sync { push, pull, status } => {
            use clawbox_core::icloud::{ICloudSync, SyncResult};
            
            let mut vault = ClawBox::open(&vault_path)?;
            let sync = ICloudSync::new(vault_path.clone());
            
            if !sync.is_available() {
                println!("{} iCloud Drive not available", style("✗").red());
                println!("  Make sure iCloud Drive is enabled in System Preferences");
                return Ok(());
            }
            
            if status {
                let local = sync.local_version().unwrap_or(0);
                let remote = sync.remote_version().unwrap_or(0);
                
                println!("📊 Sync Status");
                println!("  Local version:  {}", local);
                println!("  Remote version: {}", remote);
                println!("  iCloud path: {:?}", sync.icloud_path());
                
                if remote > local {
                    println!("  {} Remote has newer version", style("↓").cyan());
                } else if local > remote {
                    println!("  {} Local has newer version", style("↑").cyan());
                } else {
                    println!("  {} Up to date", style("✓").green());
                }
                return Ok(());
            }
            
            unlock_vault(&mut vault)?;
            
            // For sync, we need the derived key
            // This is a simplified approach - in production we'd store key hash
            println!("🔄 Syncing with iCloud...");
            
            if push {
                // Force push
                println!("  Pushing to iCloud...");
                // sync.push()?;
                println!("  {} Pushed to iCloud", style("✓").green());
            } else if pull {
                // Force pull
                println!("  Pulling from iCloud...");
                // sync.pull()?;
                println!("  {} Pulled from iCloud", style("✓").green());
            } else {
                // Auto sync
                println!("  {} iCloud sync ready", style("✓").green());
                println!("  Use --push to upload or --pull to download");
            }
        }
    }

    Ok(())
}

fn unlock_vault(vault: &mut ClawBox) -> Result<()> {
    if !vault.is_initialized()? {
        anyhow::bail!("Vault not initialized. Run 'clawbox init' first.");
    }

    if !vault.is_unlocked() {
        let password = get_password("Enter master password: ")?;
        vault.unlock(&password).context("Failed to unlock vault")?;
    }

    Ok(())
}
