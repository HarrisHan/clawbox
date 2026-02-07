// ClawBox Browser Extension - Content Script

class ClawBoxContent {
  constructor() {
    this.init();
  }

  init() {
    // Listen for messages from background
    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
      if (message.action === 'fill') {
        this.fillField(message.value, message.path);
        sendResponse({ success: true });
      }
      return true;
    });

    // Add context menu on right-click for input fields
    document.addEventListener('contextmenu', (e) => {
      if (e.target.matches('input[type="password"], input[type="text"]')) {
        // Could add context menu integration here
      }
    });
  }

  fillField(value, path) {
    // Find active/focused input field
    const activeElement = document.activeElement;
    
    if (activeElement && activeElement.matches('input, textarea')) {
      this.setInputValue(activeElement, value);
      this.showNotification(`Filled from: ${path}`);
      return;
    }

    // Try to find password field
    const passwordField = document.querySelector('input[type="password"]');
    if (passwordField) {
      this.setInputValue(passwordField, value);
      this.showNotification(`Filled password from: ${path}`);
      return;
    }

    // Try to find any visible input
    const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"])');
    for (const input of inputs) {
      if (this.isVisible(input)) {
        this.setInputValue(input, value);
        this.showNotification(`Filled from: ${path}`);
        return;
      }
    }

    this.showNotification('No input field found', 'error');
  }

  setInputValue(element, value) {
    // Set value
    element.value = value;
    
    // Trigger input events for React/Vue/Angular compatibility
    element.dispatchEvent(new Event('input', { bubbles: true }));
    element.dispatchEvent(new Event('change', { bubbles: true }));
    
    // Focus the element
    element.focus();
  }

  isVisible(element) {
    const style = window.getComputedStyle(element);
    return style.display !== 'none' && 
           style.visibility !== 'hidden' && 
           style.opacity !== '0' &&
           element.offsetParent !== null;
  }

  showNotification(message, type = 'success') {
    // Remove existing notification
    const existing = document.getElementById('clawbox-notification');
    if (existing) existing.remove();

    // Create notification
    const notification = document.createElement('div');
    notification.id = 'clawbox-notification';
    notification.innerHTML = `
      <div style="
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 12px 20px;
        background: ${type === 'success' ? '#4ecdc4' : '#ff6b6b'};
        color: ${type === 'success' ? '#1a1a2e' : '#fff'};
        border-radius: 8px;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        font-size: 14px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        z-index: 999999;
        display: flex;
        align-items: center;
        gap: 8px;
      ">
        <span style="font-size: 16px;">${type === 'success' ? '🔐' : '❌'}</span>
        <span>${message}</span>
      </div>
    `;

    document.body.appendChild(notification);

    // Auto remove after 3 seconds
    setTimeout(() => notification.remove(), 3000);
  }
}

// Initialize
new ClawBoxContent();
