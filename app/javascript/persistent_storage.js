// Persistent Storage Manager
// Handles browser storage persistence and quota management

export class PersistentStorageManager {
  constructor() {
    this.isSupported = this.checkSupport();
  }
  
  checkSupport() {
    return !!(navigator.storage && navigator.storage.persist && navigator.storage.persisted);
  }
  
  async requestPersistence() {
    if (!this.isSupported) {
      console.warn('Persistent storage not supported in this browser');
      return false;
    }
    
    // Check if already persistent
    const isPersisted = await navigator.storage.persisted();
    console.log('Storage currently persisted:', isPersisted);
    
    if (!isPersisted) {
      // Request persistent storage
      const result = await navigator.storage.persist();
      console.log('Persistence granted:', result);
      
      // Verify it worked
      const verifyPersisted = await navigator.storage.persisted();
      console.log('Storage persisted after request:', verifyPersisted);
      
      return result;
    }
    
    return true;
  }
  
  async getStorageEstimate() {
    if (navigator.storage && navigator.storage.estimate) {
      try {
        const estimate = await navigator.storage.estimate();
        
        // Some browsers don't provide quota
        const quota = estimate.quota || (50 * 1024 * 1024 * 1024); // Default to 50GB if not provided
        const usage = estimate.usage || 0;
        
        return {
          usage: usage,
          quota: quota,
          percent: quota > 0 ? (usage / quota * 100).toFixed(2) : 0,
          usageDetail: estimate.usageDetails || {}
        };
      } catch (error) {
        console.error('Error getting storage estimate:', error);
        return {
          usage: 0,
          quota: 0,
          percent: 0,
          usageDetail: {}
        };
      }
    }
    
    return null;
  }
  
  async checkPersisted() {
    if (navigator.storage && navigator.storage.persisted) {
      return await navigator.storage.persisted();
    }
    return false;
  }
  
  // Request additional quota (Chrome/Chromium specific)
  async requestQuotaIncrease(requestedBytes = 10 * 1024 * 1024 * 1024) {
    // This API is deprecated but still works in some browsers
    if (navigator.webkitPersistentStorage && navigator.webkitPersistentStorage.requestQuota) {
      return new Promise((resolve, reject) => {
        navigator.webkitPersistentStorage.requestQuota(
          requestedBytes,
          (grantedBytes) => {
            console.log('Granted storage quota:', this.formatBytes(grantedBytes));
            resolve(grantedBytes);
          },
          (error) => {
            console.error('Storage quota request failed:', error);
            reject(error);
          }
        );
      });
    }
    
    // Modern browsers automatically manage quota
    console.log('Quota management is automatic in this browser');
    return null;
  }
  
  // Get IndexedDB storage info
  async getIndexedDBInfo() {
    try {
      const dbs = await indexedDB.databases();
      const dbInfo = [];
      
      for (const dbMeta of dbs) {
        if (dbMeta.name === 'ShockCollarGallery') {
          const db = await this.openDB(dbMeta.name, dbMeta.version);
          const info = {
            name: dbMeta.name,
            version: dbMeta.version,
            stores: []
          };
          
          for (const storeName of db.objectStoreNames) {
            const tx = db.transaction([storeName], 'readonly');
            const store = tx.objectStore(storeName);
            const count = await this.promisifyRequest(store.count());
            
            info.stores.push({
              name: storeName,
              count: count
            });
          }
          
          db.close();
          dbInfo.push(info);
        }
      }
      
      return dbInfo;
    } catch (error) {
      console.error('Error getting IndexedDB info:', error);
      return [];
    }
  }
  
  openDB(name, version) {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(name, version);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }
  
  promisifyRequest(request) {
    return new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }
  
  // Clear all IndexedDB data for our app
  async clearAllStorage() {
    try {
      // Clear IndexedDB
      await indexedDB.deleteDatabase('ShockCollarGallery');
      console.log('IndexedDB cleared');
      
      // Clear Cache API
      const cacheNames = await caches.keys();
      for (const cacheName of cacheNames) {
        if (cacheName.startsWith('shock-collar-cache-')) {
          await caches.delete(cacheName);
          console.log('Cache cleared:', cacheName);
        }
      }
      
      return true;
    } catch (error) {
      console.error('Error clearing storage:', error);
      return false;
    }
  }
  
  // Utility function to format bytes
  formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    if (!bytes) return 'Unknown';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
  
  // Check if service worker has IndexedDB support
  async checkServiceWorkerStorage() {
    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      return new Promise((resolve) => {
        const messageChannel = new MessageChannel();
        
        messageChannel.port1.onmessage = (event) => {
          if (event.data && event.data.type === 'STORAGE_INFO') {
            resolve(event.data.data);
          }
        };
        
        navigator.serviceWorker.controller.postMessage(
          { type: 'GET_STORAGE_INFO' },
          [messageChannel.port2]
        );
        
        // Timeout after 2 seconds
        setTimeout(() => resolve(null), 2000);
      });
    }
    
    return null;
  }
}

// Export singleton instance
export default new PersistentStorageManager();