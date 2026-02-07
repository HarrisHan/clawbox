// ClawBox Browser Extension - Popup

class ClawBoxPopup {
  constructor() {
    this.isUnlocked = false;
    this.isInitialized = false;
    this.secrets = [];
    this.init();
  }

  init() {
    // DOM Elements
    this.initView = document.getElementById('init-view');
    this.unlockView = document.getElementById('unlock-view');
    this.secretsView = document.getElementById('secrets-view');
    this.addView = document.getElementById('add-view');
    this.status = document.getElementById('status');
    this.passwordInput = document.getElementById('password');
    this.searchInput = document.getElementById('search');
    this.secretsList = document.getElementById('secrets-list');
    this.errorMsg = document.getElementById('error-msg');

    // Event Listeners
    document.getElementById('init-btn')?.addEventListener('click', () => this.initialize());
    document.getElementById('unlock-btn').addEventListener('click', () => this.unlock());
    document.getElementById('lock-btn').addEventListener('click', () => this.lock());
    document.getElementById('add-btn').addEventListener('click', () => this.showAddView());
    document.getElementById('cancel-add').addEventListener('click', () => this.showSecretsView());
    document.getElementById('save-btn').addEventListener('click', () => this.saveSecret());
    
    this.passwordInput?.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') this.unlock();
    });

    document.getElementById('init-password')?.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') this.initialize();
    });

    this.searchInput?.addEventListener('input', () => this.filterSecrets());

    // Check status
    this.checkStatus();
  }

  async checkStatus() {
    try {
      const response = await this.sendMessage({ action: 'status' });
      this.isInitialized = response.initialized;
      
      if (!this.isInitialized) {
        this.showInitView();
      } else if (response.unlocked) {
        this.isUnlocked = true;
        this.secrets = response.secrets || [];
        this.showSecretsView();
      } else {
        this.showUnlockView();
      }
    } catch (e) {
      console.error('Status check failed:', e);
      this.showInitView();
    }
  }

  async initialize() {
    const password = document.getElementById('init-password').value;
    const confirm = document.getElementById('init-confirm').value;
    const initError = document.getElementById('init-error');
    
    if (!password) {
      initError.textContent = 'Password required';
      return;
    }
    
    if (password !== confirm) {
      initError.textContent = 'Passwords do not match';
      return;
    }

    if (password.length < 8) {
      initError.textContent = 'Password must be at least 8 characters';
      return;
    }

    try {
      const response = await this.sendMessage({ 
        action: 'init', 
        password 
      });

      if (response.success) {
        this.isUnlocked = true;
        this.isInitialized = true;
        this.secrets = [];
        initError.textContent = '';
        this.showSecretsView();
      } else {
        initError.textContent = response.error || 'Initialization failed';
      }
    } catch (e) {
      initError.textContent = 'Error: ' + e.message;
    }
  }

  async unlock() {
    const password = this.passwordInput.value;
    if (!password) return;

    try {
      const response = await this.sendMessage({ 
        action: 'unlock', 
        password 
      });

      if (response.success) {
        this.isUnlocked = true;
        this.secrets = response.secrets || [];
        this.errorMsg.textContent = '';
        this.showSecretsView();
      } else {
        this.errorMsg.textContent = response.error || 'Invalid password';
      }
    } catch (e) {
      this.errorMsg.textContent = 'Connection failed';
    }
  }

  async lock() {
    await this.sendMessage({ action: 'lock' });
    this.isUnlocked = false;
    this.secrets = [];
    this.showUnlockView();
  }

  showInitView() {
    this.initView?.classList.remove('hidden');
    this.unlockView.classList.add('hidden');
    this.secretsView.classList.add('hidden');
    this.addView.classList.add('hidden');
    this.status.textContent = '🆕';
    this.status.className = 'status new';
  }

  showUnlockView() {
    this.initView?.classList.add('hidden');
    this.unlockView.classList.remove('hidden');
    this.secretsView.classList.add('hidden');
    this.addView.classList.add('hidden');
    this.status.textContent = '🔒';
    this.status.className = 'status locked';
    this.passwordInput.value = '';
    this.passwordInput.focus();
  }

  showSecretsView() {
    this.initView?.classList.add('hidden');
    this.unlockView.classList.add('hidden');
    this.secretsView.classList.remove('hidden');
    this.addView.classList.add('hidden');
    this.status.textContent = '🔓';
    this.status.className = 'status unlocked';
    this.renderSecrets();
  }

  showAddView() {
    this.initView?.classList.add('hidden');
    this.unlockView.classList.add('hidden');
    this.secretsView.classList.add('hidden');
    this.addView.classList.remove('hidden');
    document.getElementById('new-path').value = '';
    document.getElementById('new-value').value = '';
    document.getElementById('new-path').focus();
  }

  renderSecrets() {
    const filter = this.searchInput.value.toLowerCase();
    const filtered = this.secrets.filter(s => 
      s.path.toLowerCase().includes(filter)
    );

    if (filtered.length === 0) {
      this.secretsList.innerHTML = `
        <li class="empty">
          ${this.secrets.length === 0 ? 'No secrets yet. Click + to add one.' : 'No matches found.'}
        </li>
      `;
      return;
    }

    this.secretsList.innerHTML = filtered.map(secret => `
      <li data-path="${secret.path}">
        <span class="path">${secret.path}</span>
        <div class="actions">
          <button class="copy-btn" title="Copy">📋</button>
          <button class="delete-btn" title="Delete">🗑️</button>
        </div>
      </li>
    `).join('');

    // Add click handlers
    this.secretsList.querySelectorAll('li:not(.empty)').forEach(li => {
      li.querySelector('.copy-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        this.copySecret(li.dataset.path);
      });

      li.querySelector('.delete-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        this.deleteSecret(li.dataset.path);
      });
      
      li.addEventListener('click', () => {
        this.fillSecret(li.dataset.path);
      });
    });
  }

  filterSecrets() {
    this.renderSecrets();
  }

  async copySecret(path) {
    try {
      const response = await this.sendMessage({ action: 'get', path });
      if (response.value) {
        await navigator.clipboard.writeText(response.value);
        this.showToast('Copied! (clears in 30s)');
        
        // Clear clipboard after 30 seconds
        setTimeout(async () => {
          const current = await navigator.clipboard.readText();
          if (current === response.value) {
            await navigator.clipboard.writeText('');
          }
        }, 30000);
      }
    } catch (e) {
      this.showToast('Failed to copy', 'error');
    }
  }

  async deleteSecret(path) {
    if (!confirm(`Delete "${path}"?`)) return;
    
    try {
      const response = await this.sendMessage({ action: 'delete', path });
      if (response.success) {
        this.secrets = this.secrets.filter(s => s.path !== path);
        this.renderSecrets();
        this.showToast('Deleted');
      }
    } catch (e) {
      this.showToast('Failed to delete', 'error');
    }
  }

  async fillSecret(path) {
    try {
      const response = await this.sendMessage({ action: 'get', path });
      if (response.value) {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        chrome.tabs.sendMessage(tab.id, { 
          action: 'fill', 
          value: response.value,
          path: path
        });
        window.close();
      }
    } catch (e) {
      console.error('Fill failed:', e);
    }
  }

  async saveSecret() {
    const path = document.getElementById('new-path').value.trim();
    const value = document.getElementById('new-value').value;
    
    if (!path || !value) {
      this.showToast('Path and value required', 'error');
      return;
    }

    // Validate path
    if (path.includes('..') || path.startsWith('/')) {
      this.showToast('Invalid path', 'error');
      return;
    }

    try {
      const response = await this.sendMessage({ 
        action: 'set', 
        path, 
        value 
      });

      if (response.success) {
        if (!this.secrets.find(s => s.path === path)) {
          this.secrets.push({ path });
        }
        this.showSecretsView();
        this.showToast('Saved!');
      } else {
        this.showToast(response.error || 'Save failed', 'error');
      }
    } catch (e) {
      this.showToast('Save failed', 'error');
    }
  }

  sendMessage(message) {
    return new Promise((resolve, reject) => {
      chrome.runtime.sendMessage(message, (response) => {
        if (chrome.runtime.lastError) {
          reject(chrome.runtime.lastError);
        } else {
          resolve(response || {});
        }
      });
    });
  }

  showToast(message, type = 'success') {
    const existing = document.querySelector('.toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(() => toast.remove(), 2500);
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  new ClawBoxPopup();
});
