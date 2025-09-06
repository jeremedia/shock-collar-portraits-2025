<template>
  <div class="slideshow-container">
    <div class="slideshow-header">
      <router-link to="/" class="back-button">← Gallery</router-link>
      <div class="slideshow-info">
        <span>{{ currentIndex + 1 }} / {{ heroSessions.length }}</span>
        <button @click="toggleAutoplay" class="control-btn">
          {{ isPlaying ? '⏸' : '▶' }}
        </button>
        <button @click="toggleInfo" class="control-btn">
          {{ showInfo ? 'ℹ️' : '🔲' }}
        </button>
      </div>
    </div>

    <div class="slideshow-main" @click="nextHero">
      <transition name="fade" mode="out-in">
        <img 
          v-if="currentHero"
          :key="currentHero.sessionId"
          :src="currentHero.imageUrl"
          :alt="`Hero ${currentIndex + 1}`"
          class="hero-image"
        />
      </transition>
      
      <div v-if="showInfo && currentHero" class="hero-info">
        <h3>Session {{ currentHero.sessionNumber }}</h3>
        <p>{{ formatDay(currentHero.dayOfWeek) }} • {{ formatTime(currentHero.timestamp) }}</p>
        <p>{{ currentHero.photoCount }} photos</p>
      </div>
    </div>

    <div class="progress-bar">
      <div 
        class="progress-fill" 
        :style="{ width: progressWidth }"
      ></div>
    </div>

    <div class="thumbnail-strip">
      <div 
        v-for="(hero, index) in heroSessions"
        :key="hero.sessionId"
        class="strip-thumb"
        :class="{ active: index === currentIndex }"
        @click="currentIndex = index"
      >
        <img :src="hero.thumbnailUrl" :alt="`Thumb ${index + 1}`" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useGalleryStore } from '../stores/gallery';
import api from '../services/api';

const store = useGalleryStore();

const currentIndex = ref(0);
const isPlaying = ref(false);
const showInfo = ref(false);
const autoplayInterval = ref(null);
const autoplayDuration = 5000; // 5 seconds per image

const heroSessions = computed(() => {
  return store.sessions
    .filter(session => {
      const selection = store.selections[session.id];
      return selection && selection.photoIndex !== undefined;
    })
    .map(session => {
      const selection = store.selections[session.id];
      return {
        sessionId: session.id,
        sessionNumber: session.sessionNumber || session.id.match(/\d+/)?.[0],
        dayOfWeek: session.dayOfWeek || session.dayName,
        timestamp: session.timestamp || session.date,
        photoCount: session.photoCount,
        filename: selection.filename,
        photoIndex: selection.photoIndex,
        imageUrl: api.getImageUrl(session.id, selection.filename, 'large', 'webp'),
        thumbnailUrl: api.getImageUrl(session.id, selection.filename, 'small', 'webp')
      };
    });
});

const currentHero = computed(() => {
  return heroSessions.value[currentIndex.value];
});

const progressWidth = computed(() => {
  if (heroSessions.value.length === 0) return '0%';
  return `${((currentIndex.value + 1) / heroSessions.value.length) * 100}%`;
});

const nextHero = () => {
  if (heroSessions.value.length === 0) return;
  
  if (currentIndex.value < heroSessions.value.length - 1) {
    currentIndex.value++;
  } else {
    currentIndex.value = 0; // Loop back to start
  }
};

const previousHero = () => {
  if (heroSessions.value.length === 0) return;
  
  if (currentIndex.value > 0) {
    currentIndex.value--;
  } else {
    currentIndex.value = heroSessions.value.length - 1; // Loop to end
  }
};

const toggleAutoplay = () => {
  isPlaying.value = !isPlaying.value;
  
  if (isPlaying.value) {
    startAutoplay();
  } else {
    stopAutoplay();
  }
};

const startAutoplay = () => {
  stopAutoplay(); // Clear any existing interval
  autoplayInterval.value = setInterval(() => {
    nextHero();
  }, autoplayDuration);
};

const stopAutoplay = () => {
  if (autoplayInterval.value) {
    clearInterval(autoplayInterval.value);
    autoplayInterval.value = null;
  }
};

const toggleInfo = () => {
  showInfo.value = !showInfo.value;
};

const formatDay = (day) => {
  return day ? day.charAt(0).toUpperCase() + day.slice(1) : '';
};

const formatTime = (timestamp) => {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  return date.toLocaleTimeString('en-US', { 
    hour: 'numeric', 
    minute: '2-digit',
    hour12: true 
  });
};

const handleKeyPress = (e) => {
  switch(e.key) {
    case 'ArrowLeft':
      previousHero();
      stopAutoplay();
      isPlaying.value = false;
      break;
    case 'ArrowRight':
      nextHero();
      stopAutoplay();
      isPlaying.value = false;
      break;
    case ' ':
      e.preventDefault();
      toggleAutoplay();
      break;
    case 'i':
      toggleInfo();
      break;
    case 'Escape':
      stopAutoplay();
      break;
  }
};

// Touch gesture handling
let touchStartX = 0;

const handleTouchStart = (e) => {
  touchStartX = e.touches[0].clientX;
};

const handleTouchEnd = (e) => {
  if (!touchStartX) return;
  
  const touchEndX = e.changedTouches[0].clientX;
  const deltaX = touchEndX - touchStartX;
  
  if (Math.abs(deltaX) > 50) {
    if (deltaX > 0) {
      previousHero();
    } else {
      nextHero();
    }
    stopAutoplay();
    isPlaying.value = false;
  }
  
  touchStartX = 0;
};

// Preload adjacent images for smooth transitions
watch(currentIndex, (newIndex) => {
  const nextIndex = (newIndex + 1) % heroSessions.value.length;
  const prevIndex = newIndex === 0 ? heroSessions.value.length - 1 : newIndex - 1;
  
  if (heroSessions.value[nextIndex]) {
    const next = heroSessions.value[nextIndex];
    new Image().src = api.getImageUrl(next.sessionId, next.filename, 'large', 'webp');
  }
  
  if (heroSessions.value[prevIndex]) {
    const prev = heroSessions.value[prevIndex];
    new Image().src = api.getImageUrl(prev.sessionId, prev.filename, 'large', 'webp');
  }
});

onMounted(async () => {
  await store.loadSessions();
  await store.loadSelections();
  
  document.addEventListener('keydown', handleKeyPress);
  document.addEventListener('touchstart', handleTouchStart);
  document.addEventListener('touchend', handleTouchEnd);
  
  // Start autoplay by default
  setTimeout(() => {
    isPlaying.value = true;
    startAutoplay();
  }, 1000);
});

onUnmounted(() => {
  stopAutoplay();
  document.removeEventListener('keydown', handleKeyPress);
  document.removeEventListener('touchstart', handleTouchStart);
  document.removeEventListener('touchend', handleTouchEnd);
});
</script>

<style scoped>
.slideshow-container {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: #000;
  overflow: hidden;
}

.slideshow-header {
  position: absolute;
  top: env(safe-area-inset-top, 20px);
  left: 0;
  right: 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 15px;
  background: rgba(0,0,0,0.9);
  border-bottom: 2px solid #d4af37;
  z-index: 10;
  opacity: 0;
  transition: opacity 0.3s;
}

.slideshow-container:hover .slideshow-header {
  opacity: 1;
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

.slideshow-info {
  display: flex;
  align-items: center;
  gap: 15px;
  color: #d4af37;
  font-weight: bold;
}

.control-btn {
  background: rgba(0, 0, 0, 0.8);
  border: 1px solid #d4af37;
  color: #d4af37;
  width: 35px;
  height: 35px;
  border-radius: 4px;
  cursor: pointer;
  font-size: 16px;
  transition: all 0.2s;
}

.control-btn:hover {
  background: #d4af37;
  color: #000;
}

.slideshow-main {
  position: absolute;
  top: env(safe-area-inset-top, 20px);
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  padding-top: 10px;
}

.hero-image {
  width: 100%;
  height: 100%;
  object-fit: contain;
  user-select: none;
  -webkit-user-drag: none;
}

.hero-info {
  position: absolute;
  bottom: 70px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(0, 0, 0, 0.9);
  border: 1px solid #d4af37;
  border-top: 3px solid #d4af37;
  padding: 10px 20px;
  text-align: center;
  color: #fff;
  min-width: 200px;
}

.hero-info h3 {
  color: #d4af37;
  margin: 0 0 5px 0;
  font-size: 1.2em;
  text-transform: uppercase;
}

.hero-info p {
  margin: 3px 0;
  color: #fff;
  font-size: 0.9em;
  opacity: 0.9;
}

.progress-bar {
  position: absolute;
  bottom: 50px;
  left: 0;
  right: 0;
  height: 2px;
  background: rgba(255, 255, 255, 0.1);
  z-index: 10;
}

.progress-fill {
  height: 100%;
  background: #d4af37;
  transition: width 0.3s;
  box-shadow: 0 0 5px rgba(212, 175, 55, 0.5);
}

.thumbnail-strip {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 50px;
  background: rgba(0, 0, 0, 0.95);
  border-top: 2px solid #d4af37;
  display: flex;
  overflow-x: auto;
  overflow-y: hidden;
  gap: 1px;
  padding: 4px;
  z-index: 10;
  opacity: 0;
  transition: opacity 0.3s;
}

.slideshow-container:hover .thumbnail-strip {
  opacity: 1;
}

.strip-thumb {
  flex-shrink: 0;
  width: 42px;
  height: 42px;
  cursor: pointer;
  opacity: 0.4;
  transition: all 0.2s;
  border: 1px solid transparent;
  overflow: hidden;
}

.strip-thumb:hover {
  opacity: 0.7;
  border-color: rgba(212, 175, 55, 0.5);
}

.strip-thumb.active {
  opacity: 1;
  border-color: #d4af37;
  box-shadow: 0 0 5px rgba(212, 175, 55, 0.5);
}

.strip-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* Fade transition */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.15s;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

/* Hide controls on touch devices after inactivity */
@media (hover: none) {
  .slideshow-header,
  .thumbnail-strip {
    opacity: 0;
  }
  
  .slideshow-container:active .slideshow-header,
  .slideshow-container:active .thumbnail-strip {
    opacity: 1;
  }
}
</style>