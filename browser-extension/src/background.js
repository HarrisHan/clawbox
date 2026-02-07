// ClawBox Browser Extension - Background Service Worker

const NATIVE_HOST = 'com.harrishan.clawbox';

class ClawBoxBackground {
  constructor() {
    this.port = null;
    this.isUnlocked = false;
    this.secrets = [];
    this.password = null;
    
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
  }

  async handleMessage(message) {
    switch (message.action) {
      case 'status':
        return { 
          unlocked: this.isUnlocked, 
          secrets: this.secrets 
        };

      case 'unlock':
        return await this.unlock(message.password);

      case 'lock':
        return this.lock();

      case 'get':
        return await this.getSecret(message.path);

      case 'set':
        return await this.setSecret(message.path, message.value);

      case 'list':
        return { secrets: this.secrets };

      default:
        return { error: 'Unknown action' };
    }
  }

  async unlock(password) {
    try {
      // Try to list secrets to verify password
      const result = await this.runClawbox(['list', '--json'], password);
      
      if (result.success) {
        this.isUnlocked = true;
        this.password = password;
        this.secrets = JSON.parse(result.output);
        return { success: true, secrets: this.secrets };
      } else {
        return { success: false, error: 'Invalid password' };
      }
    } catch (e) {
      return { success: false, error: e.message };
    }
  }

  lock() {
    this.isUnlocked = false;
    this.password = null;
    this.secrets = [];
    return { success: true };
  }

  async getSecret(path) {
    if (!this.isUnlocked) {
      return { error: 'Vault locked' };
    }

    try {
      const result = await this.runClawbox(['get', path], this.password);
      if (result.success) {
        return { value: result.output.trim() };
      } else {
        return { error: result.output };
      }
    } catch (e) {
      return { error: e.message };
    }
  }

  async setSecret(path, value) {
    if (!this.isUnlocked) {
      return { error: 'Vault locked' };
    }

    try {
      const result = await this.runClawbox(['set', path, value], this.password);
      if (result.success) {
        // Refresh secrets list
        this.secrets.push({ path });
        return { success: true };
      } else {
        return { error: result.output };
      }
    } catch (e) {
      return { error: e.message };
    }
  }

  async autoFill() {
    if (!this.isUnlocked) {
      // Open popup to unlock
      chrome.action.openPopup();
      return;
    }

    // Get current tab URL
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const url = new URL(tab.url);
    const domain = url.hostname;

    // Find matching secrets
    const matches = this.secrets.filter(s => 
      s.path.toLowerCase().includes(domain.toLowerCase())
    );

    if (matches.length > 0) {
      // Get and fill the first match
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

  runClawbox(args, password) {
    return new Promise((resolve) => {
      // Use native messaging if available, otherwise HTTP API
      // For now, we'll use a simple approach via native messaging
      
      try {
        const port = chrome.runtime.connectNative(NATIVE_HOST);
        
        port.onMessage.addListener((response) => {
          port.disconnect();
          resolve(response);
        });

        port.onDisconnect.addListener(() => {
          if (chrome.runtime.lastError) {
            // Native host not available, try HTTP fallback
            this.runClawboxHttp(args, password).then(resolve);
          }
        });

        port.postMessage({ args, password });
      } catch (e) {
        // Fallback to HTTP
        this.runClawboxHttp(args, password).then(resolve);
      }
    });
  }

  async runClawboxHttp(args, password) {
    // HTTP API fallback (requires local server)
    try {
      const response = await fetch('http://localhost:9876/api/clawbox', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ args, password }),
      });

      if (response.ok) {
        const data = await response.json();
        return { success: true, output: data.output };
      } else {
        return { success: false, output: 'API error' };
      }
    } catch (e) {
      // If no server, return mock for development
      console.log('No ClawBox server, using mock data');
      return this.mockClawbox(args, password);
    }
  }

  mockClawbox(args, password) {
    // Mock responses for development
    if (args[0] === 'list') {
      return {
        success: true,
        output: JSON.stringify([
          { path: 'github/token' },
          { path: 'aws/access_key' },
          { path: 'google/api_key' }
        ])
      };
    } else if (args[0] === 'get') {
      return {
        success: true,
        output: 'mock-secret-value-123'
      };
    }
    return { success: true, output: '' };
  }
}

// Initialize
new ClawBoxBackground();
