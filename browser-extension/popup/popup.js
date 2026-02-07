// ClawBox Browser Extension - Popup

class ClawBoxPopup {
  constructor() {
    this.isUnlocked = false;
    this.secrets = [];
    this.init();
  }

  init() {
    // DOM Elements
    this.unlockView = document.getElementById('unlock-view');
    this.secretsView = document.getElementById('secrets-view');
    this.addView = document.getElementById('add-view');
    this.status = document.getElementById('status');
    this.passwordInput = document.getElementById('password');
    this.searchInput = document.getElementById('search');
    this.secretsList = document.getElementById('secrets-list');
    this.errorMsg = document.getElementById('error-msg');

    // Event Listeners
    document.getElementById('unlock-btn').addEventListener('click', () => this.unlock());
    document.getElementById('lock-btn').addEventListener('click', () => this.lock());
    document.getElementById('add-btn').addEventListener('click', () => this.showAddView());
    document.getElementById('cancel-add').addEventListener('click', () => this.showSecretsView());
    document.getElementById('save-btn').addEventListener('click', () => this.saveSecret());
    
    this.passwordInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') this.unlock();
    });

    this.searchInput.addEventListener('input', () => this.filterSecrets());

    // Check if already unlocked
    this.checkStatus();
  }

  async checkStatus() {
    try {
      const response = await this.sendMessage({ action: 'status' });
      if (response.unlocked) {
        this.isUnlocked = true;
        this.secrets = response.secrets || [];
        this.showSecretsView();
      }
    } catch (e) {
      console.log('Not connected to native host');
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
      this.errorMsg.textContent = 'Connection failed. Is ClawBox installed?';
    }
  }

  async lock() {
    await this.sendMessage({ action: 'lock' });
    this.isUnlocked = false;
    this.secrets = [];
    this.showUnlockView();
  }

  showUnlockView() {
    this.unlockView.classList.remove('hidden');
    this.secretsView.classList.add('hidden');
    this.addView.classList.add('hidden');
    this.status.textContent = '🔒';
    this.status.className = 'status locked';
    this.passwordInput.value = '';
    this.passwordInput.focus();
  }

  showSecretsView() {
    this.unlockView.classList.add('hidden');
    this.secretsView.classList.remove('hidden');
    this.addView.classList.add('hidden');
    this.status.textContent = '🔓';
    this.status.className = 'status unlocked';
    this.renderSecrets();
  }

  showAddView() {
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

    this.secretsList.innerHTML = filtered.map(secret => `
      <li data-path="${secret.path}">
        <span class="path">${secret.path}</span>
        <button class="copy-btn" title="Copy to clipboard">📋</button>
      </li>
    `).join('');

    // Add click handlers
    this.secretsList.querySelectorAll('li').forEach(li => {
      li.querySelector('.copy-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        this.copySecret(li.dataset.path);
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
        this.showToast('Copied!');
      }
    } catch (e) {
      this.showToast('Failed to copy');
    }
  }

  async fillSecret(path) {
    try {
      const response = await this.sendMessage({ action: 'get', path });
      if (response.value) {
        // Send to content script to fill
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
    const path = document.getElementById('new-path').value;
    const value = document.getElementById('new-value').value;
    
    if (!path || !value) return;

    try {
      const response = await this.sendMessage({ 
        action: 'set', 
        path, 
        value 
      });

      if (response.success) {
        this.secrets.push({ path });
        this.showSecretsView();
      }
    } catch (e) {
      console.error('Save failed:', e);
    }
  }

  sendMessage(message) {
    return new Promise((resolve, reject) => {
      chrome.runtime.sendMessage(message, (response) => {
        if (chrome.runtime.lastError) {
          reject(chrome.runtime.lastError);
        } else {
          resolve(response);
        }
      });
    });
  }

  showToast(message) {
    // Simple toast notification
    const toast = document.createElement('div');
    toast.textContent = message;
    toast.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: #4ecdc4;
      color: #1a1a2e;
      padding: 8px 16px;
      border-radius: 4px;
      font-size: 12px;
    `;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 2000);
  }
}

// Initialize
new ClawBoxPopup();
