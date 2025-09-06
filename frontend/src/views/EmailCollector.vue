<template>
  <div class="email-collector">
    <header class="collector-header">
      <router-link to="/" class="back-button">← Gallery</router-link>
      <h2>Email Collection</h2>
      <div class="stats">
        {{ emailStore.totalEmails }} collected
      </div>
    </header>

    <div class="quick-entry">
      <h3>Session {{ nextSessionNumber }} Sitter Info</h3>
      <form @submit.prevent="quickSave" class="entry-form">
        <input 
          v-model="quickForm.name" 
          type="text" 
          placeholder="Name (optional)"
          class="input-field"
          autocomplete="off"
        />
        
        <input 
          v-model="quickForm.email" 
          type="email" 
          placeholder="Email address *"
          class="input-field"
          required
          autocomplete="off"
          autocapitalize="off"
          autocorrect="off"
          spellcheck="false"
          ref="emailInput"
        />
        
        <!-- Session number hidden - auto-managed -->
        <input 
          v-model="quickForm.sessionNumber" 
          type="hidden" 
          placeholder="Session #"
          class="input-field small"
          min="1"
          required
        />
        
        <button type="submit" class="save-btn">
          Save & Next
        </button>
      </form>
      
      <div v-if="lastSaved" class="last-saved">
        ✓ Saved: {{ lastSaved.name || 'No name' }} - {{ lastSaved.email }}
      </div>
    </div>

    <!-- Admin actions hidden for participant self-entry -->
    <!-- <div class="actions">
      <button @click="exportForMailMerge" class="action-btn">
        📧 Export for Mail Merge
      </button>
      <button @click="exportAsCSV" class="action-btn">
        📊 Export CSV
      </button>
      <button @click="showImport = !showImport" class="action-btn">
        📥 Import
      </button>
    </div>

    <div v-if="showImport" class="import-section">
      <textarea 
        v-model="importData" 
        placeholder="Paste email data here (JSON or list)"
        class="import-field"
      ></textarea>
      <button @click="importEmails" class="action-btn">
        Process Import
      </button>
    </div> -->

    <!-- Recent entries list hidden for participant self-entry -->
    <!-- <div class="email-list">
      <h3>Recent Entries</h3>
      <div class="list-container">
        <div 
          v-for="entry in recentEntries" 
          :key="entry.sessionId"
          class="email-entry"
        >
          <div class="entry-main">
            <span class="session-num">{{ entry.sessionNumber }}</span>
            <div class="entry-details">
              <div class="entry-name">{{ entry.name || 'No name' }}</div>
              <div class="entry-email">{{ entry.email }}</div>
            </div>
          </div>
          <button @click="removeEntry(entry.sessionId)" class="remove-btn">
            ✕
          </button>
        </div>
      </div>
    </div> -->

    <div class="keyboard-spacer"></div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue';
import { useEmailStore } from '../stores/emails';
import { useGalleryStore } from '../stores/gallery';

const emailStore = useEmailStore();
const galleryStore = useGalleryStore();

const quickForm = ref({
  name: '',
  email: '',
  sessionNumber: ''
});

const lastSaved = ref(null);
const showImport = ref(false);
const importData = ref('');
const emailInput = ref(null);

// Calculate next session number
const nextSessionNumber = computed(() => {
  if (quickForm.value.sessionNumber) {
    return quickForm.value.sessionNumber;
  }
  // Find highest session number and add 1
  const numbers = emailStore.emailsList.map(e => parseInt(e.sessionNumber) || 0);
  const highest = Math.max(0, ...numbers);
  return highest + 1;
});

// Get recent entries (last 20)
const recentEntries = computed(() => {
  return emailStore.emailsList.slice(-20).reverse();
});

// Quick save function
async function quickSave() {
  const sessionNum = quickForm.value.sessionNumber || nextSessionNumber.value;
  const sessionId = `burst_${String(sessionNum).padStart(3, '0')}_manual`;
  
  emailStore.saveEmail(sessionId, {
    name: quickForm.value.name,
    email: quickForm.value.email,
    sessionNumber: sessionNum,
    notes: 'Quick entry'
  });
  
  // Show confirmation
  lastSaved.value = {
    name: quickForm.value.name,
    email: quickForm.value.email
  };
  
  // Clear form for next entry
  quickForm.value = {
    name: '',
    email: '',
    sessionNumber: String(parseInt(sessionNum) + 1)
  };
  
  // Refocus email input
  await nextTick();
  emailInput.value?.focus();
  
  // Clear confirmation after 3 seconds
  setTimeout(() => {
    lastSaved.value = null;
  }, 3000);
}

// Remove entry
function removeEntry(sessionId) {
  if (confirm('Remove this email?')) {
    emailStore.removeEmail(sessionId);
  }
}

// Export functions
function exportForMailMerge() {
  emailStore.exportForMailMerge();
}

function exportAsCSV() {
  emailStore.exportAsCSV();
}

// Import emails from paste
function importEmails() {
  const data = importData.value.trim();
  
  if (!data) return;
  
  try {
    // Try parsing as JSON first
    const jsonData = JSON.parse(data);
    if (emailStore.importEmails(jsonData)) {
      alert(`Imported ${Object.keys(jsonData.emails || {}).length} emails`);
      importData.value = '';
      showImport.value = false;
      return;
    }
  } catch {
    // Not JSON, try parsing as list
    const lines = data.split('\n');
    const emails = {};
    let imported = 0;
    
    lines.forEach(line => {
      // Parse various formats
      // Format 1: "1. Name - email@domain.com"
      // Format 2: "email@domain.com"
      // Format 3: "Name [email@domain.com]"
      
      const emailRegex = /[\w._%+-]+@[\w.-]+\.[A-Z|a-z]{2,}/gi;
      const emailMatch = line.match(emailRegex);
      
      if (emailMatch) {
        const email = emailMatch[0];
        const sessionMatch = line.match(/^(\d+)/);
        const sessionNum = sessionMatch ? sessionMatch[1] : imported + 1;
        
        // Extract name (everything before email, cleaned up)
        let name = line.split(email)[0]
          .replace(/^\d+\.?\s*/, '') // Remove number
          .replace(/[-\[\(]\s*$/, '') // Remove trailing separators
          .trim();
        
        const sessionId = `burst_${String(sessionNum).padStart(3, '0')}_imported`;
        
        emails[sessionId] = {
          name,
          email,
          sessionNumber: sessionNum,
          notes: 'Imported',
          timestamp: new Date().toISOString()
        };
        
        imported++;
      }
    });
    
    if (imported > 0) {
      emailStore.importEmails({ emails });
      alert(`Imported ${imported} emails`);
      importData.value = '';
      showImport.value = false;
    } else {
      alert('No valid emails found in the data');
    }
  }
}

onMounted(() => {
  emailStore.loadEmails();
  galleryStore.loadSessions();
  
  // Set initial session number
  const numbers = emailStore.emailsList.map(e => parseInt(e.sessionNumber) || 0);
  const highest = Math.max(0, ...numbers);
  quickForm.value.sessionNumber = String(highest + 1);
  
  // Focus email input
  emailInput.value?.focus();
});
</script>

<style scoped>
.email-collector {
  min-height: 100vh;
  background: #1a1a1a;
  color: white;
  padding-bottom: env(safe-area-inset-bottom, 20px);
}

.collector-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px;
  padding-top: calc(20px + env(safe-area-inset-top, 0px));
  background: #000;
  border-bottom: 2px solid #d4af37;
}

.back-button {
  color: #d4af37;
  text-decoration: none;
  font-size: 1.1em;
}

.stats {
  color: #d4af37;
  font-weight: bold;
}

.quick-entry {
  padding: 20px;
  background: rgba(0, 0, 0, 0.8);
  border-bottom: 1px solid #c9302c;
}

.quick-entry h3 {
  color: #d4af37;
  margin: 0 0 15px 0;
  text-transform: uppercase;
}

.entry-form {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.input-field {
  padding: 15px;
  font-size: 16px; /* Prevents zoom on iOS */
  background: #000;
  border: 2px solid #c9302c;
  color: white;
  border-radius: 8px;
  -webkit-appearance: none;
}

.input-field:focus {
  outline: none;
  border-color: #d4af37;
  box-shadow: 0 0 10px rgba(212, 175, 55, 0.3);
}

.input-field.small {
  width: 120px;
}

.save-btn {
  padding: 15px;
  font-size: 18px;
  font-weight: bold;
  background: #d4af37;
  color: #000;
  border: none;
  border-radius: 8px;
  text-transform: uppercase;
  cursor: pointer;
}

.save-btn:active {
  background: #c9302c;
  color: white;
}

.last-saved {
  margin-top: 15px;
  padding: 10px;
  background: rgba(212, 175, 55, 0.2);
  border-left: 3px solid #d4af37;
  color: #d4af37;
  animation: fadeIn 0.3s;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

.actions {
  padding: 20px;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.action-btn {
  flex: 1;
  min-width: 140px;
  padding: 12px;
  background: #c9302c;
  color: white;
  border: 2px solid #d4af37;
  border-radius: 6px;
  font-weight: bold;
  cursor: pointer;
}

.action-btn:active {
  background: #d4af37;
  color: #000;
}

.import-section {
  padding: 20px;
  background: rgba(0, 0, 0, 0.8);
}

.import-field {
  width: 100%;
  min-height: 150px;
  padding: 10px;
  background: #000;
  border: 2px solid #c9302c;
  color: white;
  border-radius: 8px;
  font-family: monospace;
  margin-bottom: 10px;
}

.email-list {
  padding: 20px;
}

.email-list h3 {
  color: #d4af37;
  margin: 0 0 15px 0;
  text-transform: uppercase;
}

.list-container {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.email-entry {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px;
  background: rgba(0, 0, 0, 0.8);
  border: 1px solid #c9302c;
  border-radius: 8px;
}

.entry-main {
  display: flex;
  align-items: center;
  gap: 15px;
  flex: 1;
}

.session-num {
  display: inline-block;
  min-width: 40px;
  padding: 5px 10px;
  background: #d4af37;
  color: #000;
  border-radius: 4px;
  font-weight: bold;
  text-align: center;
}

.entry-details {
  flex: 1;
}

.entry-name {
  font-weight: bold;
  color: #d4af37;
}

.entry-email {
  color: #fff;
  font-size: 0.9em;
  opacity: 0.9;
}

.remove-btn {
  width: 30px;
  height: 30px;
  background: #c9302c;
  color: white;
  border: none;
  border-radius: 50%;
  cursor: pointer;
  font-weight: bold;
}

.keyboard-spacer {
  height: 100px; /* Space for iOS keyboard */
}

/* Optimize for iPhone */
@media (max-width: 430px) {
  .input-field {
    font-size: 16px; /* Prevents zoom */
  }
  
  .actions {
    flex-direction: column;
  }
  
  .action-btn {
    width: 100%;
  }
}
</style>