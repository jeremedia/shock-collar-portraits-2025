<template>
  <div class="session-viewer">
    <header class="session-header">
      <router-link :to="{ path: '/', hash: `#session-${session?.id || ''}` }" class="back-button">← Gallery</router-link>
      <h2>Session {{ sessionNumber }}</h2>
      <div class="session-nav">
        <button 
          v-if="adjacentSessions.prev"
          @click="goToSession(adjacentSessions.prev)"
          class="nav-button"
        >
          ← Prev
        </button>
        <button 
          v-if="adjacentSessions.next"
          @click="goToSession(adjacentSessions.next)"
          class="nav-button"
        >
          Next →
        </button>
      </div>
    </header>

    <div v-if="session" class="viewer-content">
      <div class="main-image-container">
        <img 
          :src="currentImageUrl"
          :alt="`Photo ${currentIndex + 1}`"
          class="main-image"
          @click="nextImage"
        />
        <div class="image-controls">
          <button @click="previousImage" class="control-button">←</button>
          <span class="image-counter">{{ currentIndex + 1 }} / {{ session.photos.length }}</span>
          <button @click="nextImage" class="control-button">→</button>
        </div>
        <button 
          @click="toggleSelection"
          class="select-button"
          :class="{ selected: isSelected }"
        >
          {{ isSelected ? '★ Selected' : '☆ Select as Hero' }}
        </button>
        
        <!-- Email Collection -->
        <div class="email-section">
          <button 
            v-if="!showEmailForm && !sessionEmail"
            @click="showEmailForm = true"
            class="email-toggle-btn"
          >
            📧 Add Email
          </button>
          
          <div v-if="sessionEmail" class="email-saved">
            ✓ {{ sessionEmail.name || 'No name' }} - {{ sessionEmail.email }}
            <button @click="showEmailForm = true" class="edit-btn">Edit</button>
          </div>
          
          <div v-if="showEmailForm" class="email-form">
            <input 
              v-model="emailForm.name"
              type="text"
              placeholder="Name (optional)"
              class="email-input"
              autocomplete="off"
            />
            <input 
              v-model="emailForm.email"
              type="email"
              placeholder="Email address"
              class="email-input"
              required
              autocomplete="off"
              autocapitalize="off"
              autocorrect="off"
              spellcheck="false"
            />
            <button @click="saveEmail" class="save-email-btn">Save</button>
            <button @click="showEmailForm = false" class="cancel-btn">Cancel</button>
          </div>
        </div>
      </div>

      <div class="thumbnails-container">
        <div class="thumbnails-scroll">
          <div 
            v-for="(photo, index) in session.photos"
            :key="photo.filename"
            class="thumbnail"
            :class="{ 
              active: index === currentIndex,
              selected: selections[session.id || session.session_id]?.photoIndex === index
            }"
            @click="currentIndex = index"
          >
            <img 
              :src="getThumbnailUrl(photo.filename)"
              :alt="`Thumbnail ${index + 1}`"
              loading="lazy"
            />
          </div>
        </div>
      </div>
    </div>

    <div v-if="loading" class="loading">Loading session...</div>
    <div v-if="error" class="error">{{ error }}</div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useGalleryStore } from '../stores/gallery';
import { useEmailStore } from '../stores/emails';
import api from '../services/api';

const props = defineProps({
  id: {
    type: String,
    required: true
  }
});

const route = useRoute();
const router = useRouter();
const store = useGalleryStore();
const emailStore = useEmailStore();

const session = ref(null);
const currentIndex = ref(0);
const adjacentSessions = ref({ prev: null, next: null });
const loading = computed(() => store.loading);
const error = computed(() => store.error);
const selections = computed(() => store.selections);

// Email collection
const showEmailForm = ref(false);
const emailForm = ref({
  name: '',
  email: ''
});
const emailSaved = ref(false);

const sessionNumber = computed(() => {
  if (!session.value) return '';
  const sessionId = session.value.id || session.value.session_id;
  const match = sessionId.match(/burst_(\d+)/);
  return match ? match[1] : sessionId;
});

const currentImageUrl = computed(() => {
  if (!session.value || !session.value.photos) return '';
  const photo = session.value.photos[currentIndex.value];
  if (!photo) return '';
  
  // Use Active Storage URL if available
  if (photo.urls && photo.urls.large) {
    return photo.urls.large;
  }
  
  // Fallback to direct file serving
  const sessionId = session.value.id || session.value.session_id;
  return api.getImageUrl(sessionId, photo.filename, 'large', 'webp');
});

const isSelected = computed(() => {
  if (!session.value) return false;
  const sessionId = session.value.id || session.value.session_id;
  return selections.value[sessionId]?.photoIndex === currentIndex.value;
});

const sessionEmail = computed(() => {
  if (!session.value) return null;
  const sessionId = session.value.id || session.value.session_id;
  return emailStore.getEmail(sessionId);
});

const getThumbnailUrl = (filename) => {
  // Find the photo object to check for Active Storage URL
  const photo = session.value.photos.find(p => p.filename === filename);
  
  // Use Active Storage URL if available
  if (photo && photo.urls && photo.urls.thumb) {
    return photo.urls.thumb;
  }
  
  // Fallback to direct file serving
  const sessionId = session.value.id || session.value.session_id;
  return api.getImageUrl(sessionId, filename, 'small', 'webp');
};

const previousImage = () => {
  if (currentIndex.value > 0) {
    currentIndex.value--;
  } else if (adjacentSessions.value.prev) {
    // At first image, go to previous session starting at its last image
    goToSession(adjacentSessions.value.prev, 'last');
  } else {
    // No previous session, wrap to last image
    currentIndex.value = session.value.photos.length - 1;
  }
};

const nextImage = () => {
  if (currentIndex.value < session.value.photos.length - 1) {
    currentIndex.value++;
  } else if (adjacentSessions.value.next) {
    // At last image, go to next session starting at its first image
    goToSession(adjacentSessions.value.next, 'first');
  } else {
    // No next session, wrap to first image
    currentIndex.value = 0;
  }
};

const toggleSelection = async () => {
  if (!session.value) return;
  
  const sessionId = session.value.id || session.value.session_id;
  
  if (isSelected.value) {
    await store.removeSelection(sessionId);
  } else {
    const photo = session.value.photos[currentIndex.value];
    await store.saveSelection(
      sessionId, 
      currentIndex.value, 
      photo.filename
    );
  }
};

const saveEmail = () => {
  if (!session.value || !emailForm.value.email) return;
  
  const sessionId = session.value.id || session.value.session_id;
  const sessionNum = sessionNumber.value;
  
  emailStore.saveEmail(sessionId, {
    name: emailForm.value.name,
    email: emailForm.value.email,
    sessionNumber: sessionNum,
    notes: 'Collected during session'
  });
  
  showEmailForm.value = false;
  emailSaved.value = true;
  
  // Clear saved indicator after 3 seconds
  setTimeout(() => {
    emailSaved.value = false;
  }, 3000);
  
  // If there's an existing email, populate form for editing
  const existing = emailStore.getEmail(sessionId);
  if (existing) {
    emailForm.value.name = existing.name || '';
    emailForm.value.email = existing.email || '';
  }
};

const goToSession = (sessionId, startAt = 'default') => {
  // Pass the starting position as a query parameter
  router.push({ 
    name: 'session', 
    params: { id: sessionId },
    query: { start: startAt }
  });
};

const handleKeyPress = (e) => {
  switch(e.key) {
    case 'ArrowLeft':
      previousImage();
      break;
    case 'ArrowRight':
      nextImage();
      break;
    case ' ':
      e.preventDefault();
      toggleSelection();
      break;
    case 'Escape':
      router.push('/');
      break;
  }
};

const loadSession = async () => {
  const data = await store.loadSession(props.id);
  if (data) {
    session.value = data;
    
    // Load existing email if present
    const sessionId = data.id || data.session_id;
    const existingEmail = emailStore.getEmail(sessionId);
    if (existingEmail) {
      emailForm.value.name = existingEmail.name || '';
      emailForm.value.email = existingEmail.email || '';
    }
    
    const adjacent = await api.getAdjacentSessions(props.id);
    adjacentSessions.value = adjacent;
    
    // Check for start position from query parameter
    const startPosition = route.query.start;
    if (startPosition === 'last') {
      currentIndex.value = data.photos.length - 1;
    } else if (startPosition === 'first') {
      currentIndex.value = 0;
    } else {
      // Default: use selection or start at beginning
      // Make sure selections are loaded first
      if (Object.keys(selections.value).length === 0) {
        await store.loadSelections();
      }
      
      const sessionId = data.id || data.session_id;
      const selection = selections.value[sessionId];
      if (selection) {
        currentIndex.value = selection.photoIndex;
      } else {
        currentIndex.value = 0;
      }
    }
    
    if (data.photos.length > 1) {
      const nextPhotos = data.photos.slice(1, 6).map(p => p.filename);
      store.preloadImages(props.id, nextPhotos, 'large');
    }
  }
};

watch(() => props.id, loadSession);

onMounted(async () => {
  document.addEventListener('keydown', handleKeyPress);
  
  // Load emails
  emailStore.loadEmails();
  
  // Add swipe gestures for touch devices
  let touchStartX = 0;
  let touchStartY = 0;
  
  const handleTouchStart = (e) => {
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
  };
  
  const handleTouchEnd = (e) => {
    if (!touchStartX) return;
    
    const touchEndX = e.changedTouches[0].clientX;
    const touchEndY = e.changedTouches[0].clientY;
    
    const deltaX = touchEndX - touchStartX;
    const deltaY = touchEndY - touchStartY;
    
    // Check if horizontal swipe
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
      if (deltaX > 0) {
        previousImage(); // Swipe right
      } else {
        nextImage(); // Swipe left
      }
    }
    
    touchStartX = 0;
    touchStartY = 0;
  };
  
  document.addEventListener('touchstart', handleTouchStart);
  document.addEventListener('touchend', handleTouchEnd);
  
  // Ensure selections are loaded before loading the session
  await store.loadSelections();
  loadSession();
  
  // Cleanup on unmount
  onUnmounted(() => {
    document.removeEventListener('keydown', handleKeyPress);
    document.removeEventListener('touchstart', handleTouchStart);
    document.removeEventListener('touchend', handleTouchEnd);
  });
});
</script>

<style scoped>
.session-viewer {
  min-height: 100vh;
  background: #1a1a1a;
  color: white;
}

.session-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px;
  padding-top: calc(20px + env(safe-area-inset-top, 0px));
  background: rgba(0,0,0,0.5);
}

.back-button {
  color: #d4af37;
  text-decoration: none;
  font-size: 1.1em;
  transition: color 0.2s;
}

.back-button:hover {
  color: #f0c843;
}

.session-nav {
  display: flex;
  gap: 10px;
}

.nav-button {
  padding: 8px 16px;
  background: #333;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background 0.2s;
}

.nav-button:hover {
  background: #444;
}

.viewer-content {
  padding: 20px;
}

.main-image-container {
  position: relative;
  max-width: 100%;
  margin: 0 auto 30px;
  text-align: center;
}

.main-image {
  max-width: 100%;
  max-height: 70vh;
  cursor: pointer;
  border-radius: 8px;
}

.image-controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 20px;
  margin-top: 20px;
}

.control-button {
  width: 50px;
  height: 50px;
  font-size: 24px;
  background: #333;
  color: white;
  border: none;
  border-radius: 50%;
  cursor: pointer;
  transition: background 0.2s;
}

.control-button:hover {
  background: #444;
}

.image-counter {
  font-size: 1.1em;
  color: #ccc;
}

.select-button {
  margin-top: 20px;
  padding: 12px 24px;
  font-size: 1.1em;
  background: #333;
  color: white;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.select-button:hover {
  background: #444;
}

.select-button.selected {
  background: #d4af37;
  color: black;
}

.thumbnails-container {
  overflow-x: auto;
  padding: 10px 0;
}

.thumbnails-scroll {
  display: flex;
  gap: 10px;
  padding-bottom: 10px;
}

.thumbnail {
  flex-shrink: 0;
  width: 100px;
  height: 100px;
  cursor: pointer;
  opacity: 0.6;
  transition: all 0.2s;
  border: 2px solid transparent;
  border-radius: 4px;
  overflow: hidden;
}

.thumbnail:hover {
  opacity: 0.9;
}

.thumbnail.active {
  opacity: 1;
  border-color: white;
}

.thumbnail.selected {
  border-color: #d4af37;
}

.thumbnail img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.loading, .error {
  text-align: center;
  padding: 40px;
  font-size: 1.2em;
}

.error {
  color: #ff6b6b;
}

/* Email Collection Styles */
.email-section {
  margin-top: 20px;
  padding: 15px;
  background: rgba(0, 0, 0, 0.3);
  border-radius: 8px;
  border: 1px solid #333;
}

.email-toggle-btn {
  padding: 10px 20px;
  background: #c9302c;
  color: white;
  border: 2px solid #d4af37;
  border-radius: 6px;
  font-weight: bold;
  cursor: pointer;
}

.email-toggle-btn:hover {
  background: #d4af37;
  color: #000;
}

.email-saved {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px;
  background: rgba(212, 175, 55, 0.2);
  border-left: 3px solid #d4af37;
  color: #d4af37;
}

.edit-btn {
  padding: 5px 10px;
  background: #333;
  color: white;
  border: 1px solid #d4af37;
  border-radius: 4px;
  cursor: pointer;
}

.email-form {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.email-input {
  padding: 10px;
  background: #000;
  border: 2px solid #c9302c;
  color: white;
  border-radius: 6px;
  font-size: 16px;
}

.email-input:focus {
  outline: none;
  border-color: #d4af37;
}

.save-email-btn {
  padding: 10px;
  background: #d4af37;
  color: #000;
  border: none;
  border-radius: 6px;
  font-weight: bold;
  cursor: pointer;
}

.cancel-btn {
  padding: 10px;
  background: #333;
  color: white;
  border: 1px solid #666;
  border-radius: 6px;
  cursor: pointer;
}

.save-email-btn:hover {
  background: #c9302c;
  color: white;
}
</style>