// ClawBox Browser Extension - Background Service Worker
// Standalone version using chrome.storage

class ClawBoxBackground {
  constructor() {
    this.isUnlocked = false;
    this.secrets = [];
    this.masterKey = null;
    
    this.init();
  }

  init() {
    // Listen for messages from popup
    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
      this.handleMessage(message).then(sendResponse);
      return true; // Async response
    });

    // Listen for keyboard shortcuts
    chrome.commands.onCommand.addListener((command) => {
      if (command === 'fill-credentials') {
        this.autoFill();
      }
    });

    // Check if already initialized
    this.checkStatus();
  }

  async checkStatus() {
    const data = await chrome.storage.local.get(['salt', 'verification']);
    return data.salt != null;
  }

  async handleMessage(message) {
    switch (message.action) {
      case 'status':
        return { 
          unlocked: this.isUnlocked, 
          secrets: this.secrets,
          initialized: await this.checkStatus()
        };

      case 'init':
        return await this.initialize(message.password);

      case 'unlock':
        return await this.unlock(message.password);

      case 'lock':
        return this.lock();

      case 'get':
        return await this.getSecret(message.path);

      case 'set':
        return await this.setSecret(message.path, message.value);

      case 'delete':
        return await this.deleteSecret(message.path);

      case 'list':
        return { secrets: this.secrets };

      default:
        return { error: 'Unknown action' };
    }
  }

  // Crypto helpers using Web Crypto API
  async deriveKey(password, salt) {
    const encoder = new TextEncoder();
    const keyMaterial = await crypto.subtle.importKey(
      'raw',
      encoder.encode(password),
      'PBKDF2',
      false,
      ['deriveKey']
    );

    return await crypto.subtle.deriveKey(
      {
        name: 'PBKDF2',
        salt: salt,
        iterations: 100000,
        hash: 'SHA-256'
      },
      keyMaterial,
      { name: 'AES-GCM', length: 256 },
      false,
      ['encrypt', 'decrypt']
    );
  }

  async encrypt(data, key) {
    const encoder = new TextEncoder();
    const iv = crypto.getRandomValues(new Uint8Array(12));
    
    const encrypted = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv },
      key,
      encoder.encode(data)
    );

    // Combine IV + ciphertext
    const combined = new Uint8Array(iv.length + encrypted.byteLength);
    combined.set(iv);
    combined.set(new Uint8Array(encrypted), iv.length);
    
    return this.arrayBufferToBase64(combined);
  }

  async decrypt(encryptedBase64, key) {
    const combined = this.base64ToArrayBuffer(encryptedBase64);
    const iv = combined.slice(0, 12);
    const ciphertext = combined.slice(12);

    const decrypted = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv },
      key,
      ciphertext
    );

    return new TextDecoder().decode(decrypted);
  }

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }

  base64ToArrayBuffer(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  // Vault operations
  async initialize(password) {
    try {
      const salt = crypto.getRandomValues(new Uint8Array(32));
      const key = await this.deriveKey(password, salt);
      
      // Create verification token
      const verification = await this.encrypt('clawbox-ok', key);
      
      await chrome.storage.local.set({
        salt: this.arrayBufferToBase64(salt),
        verification: verification,
        secrets: {}
      });

      this.masterKey = key;
      this.isUnlocked = true;
      this.secrets = [];
      
      return { success: true };
    } catch (e) {
      return { success: false, error: e.message };
    }
  }

  async unlock(password) {
    try {
      const data = await chrome.storage.local.get(['salt', 'verification', 'secrets']);
      
      if (!data.salt) {
        return { success: false, error: 'Not initialized' };
      }

      const salt = this.base64ToArrayBuffer(data.salt);
      const key = await this.deriveKey(password, salt);

      // Verify password
      try {
        const decrypted = await this.decrypt(data.verification, key);
        if (decrypted !== 'clawbox-ok') {
          return { success: false, error: 'Invalid password' };
        }
      } catch {
        return { success: false, error: 'Invalid password' };
      }

      this.masterKey = key;
      this.isUnlocked = true;

      // Load secrets list
      this.secrets = Object.keys(data.secrets || {}).map(path => ({ path }));

      return { success: true, secrets: this.secrets };
    } catch (e) {
      return { success: false, error: e.message };
    }
  }

  lock() {
    this.masterKey = null;
    this.isUnlocked = false;
    this.secrets = [];
    return { success: true };
  }

  async getSecret(path) {
    if (!this.isUnlocked || !this.masterKey) {
      return { error: 'Vault locked' };
    }

    try {
      const data = await chrome.storage.local.get(['secrets']);
      const secrets = data.secrets || {};
      
      if (!secrets[path]) {
        return { error: 'Not found' };
      }

      const value = await this.decrypt(secrets[path], this.masterKey);
      return { value };
    } catch (e) {
      return { error: e.message };
    }
  }

  async setSecret(path, value) {
    if (!this.isUnlocked || !this.masterKey) {
      return { error: 'Vault locked' };
    }

    try {
      const data = await chrome.storage.local.get(['secrets']);
      const secrets = data.secrets || {};
      
      secrets[path] = await this.encrypt(value, this.masterKey);
      
      await chrome.storage.local.set({ secrets });

      // Update list
      if (!this.secrets.find(s => s.path === path)) {
        this.secrets.push({ path });
      }

      return { success: true };
    } catch (e) {
      return { error: e.message };
    }
  }

  async deleteSecret(path) {
    if (!this.isUnlocked || !this.masterKey) {
      return { error: 'Vault locked' };
    }

    try {
      const data = await chrome.storage.local.get(['secrets']);
      const secrets = data.secrets || {};
      
      delete secrets[path];
      
      await chrome.storage.local.set({ secrets });
      this.secrets = this.secrets.filter(s => s.path !== path);

      return { success: true };
    } catch (e) {
      return { error: e.message };
    }
  }

  async autoFill() {
    if (!this.isUnlocked) {
      chrome.action.openPopup();
      return;
    }

    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const url = new URL(tab.url);
    const domain = url.hostname.replace('www.', '');

    // Find matching secrets
    const matches = this.secrets.filter(s => 
      s.path.toLowerCase().includes(domain.toLowerCase())
    );

    if (matches.length > 0) {
      const secret = await this.getSecret(matches[0].path);
      if (secret.value) {
        chrome.tabs.sendMessage(tab.id, {
          action: 'fill',
          value: secret.value,
          path: matches[0].path
        });
      }
    }
  }
}

// Initialize
new ClawBoxBackground();
