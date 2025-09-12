<template>
  <div 
    class="session-card"
    :class="{ selected }"
    @click="$emit('click')"
  >
    <div class="image-container">
      <img 
        :src="thumbnailUrl"
        :alt="`Session ${session.id}`"
        loading="lazy"
        @error="handleImageError"
      />
      <div v-if="selected" class="selected-badge">✓</div>
    </div>
    <div class="session-info">
      <h4>Session {{ sessionNumber }}</h4>
      <p class="session-time">{{ formatTime(session.timestamp || session.date) }}</p>
      <p class="session-stats">
        {{ session.photoCount }} photos
        <span v-if="session.duration > 0">• {{ formatDuration(session.duration) }}</span>
      </p>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import api from '../services/api';

const props = defineProps({
  session: {
    type: Object,
    required: true
  },
  selected: {
    type: Boolean,
    default: false
  }
});

defineEmits(['click']);

const sessionNumber = computed(() => {
  const match = props.session.id.match(/burst_(\d+)/);
  return match ? match[1] : props.session.id;
});

const thumbnailUrl = computed(() => {
  // Check if we have an Active Storage URL first
  if (props.session.heroPhotoUrl) {
    return props.session.heroPhotoUrl;
  }
  
  const photo = props.session.heroPhoto || props.session.firstPhoto;
  if (!photo) {
    // Return a placeholder if no photo available
    return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iI2NjYyIvPjx0ZXh0IHRleHQtYW5jaG9yPSJtaWRkbGUiIHg9IjEwMCIgeT0iMTAwIiBmaWxsPSIjOTk5IiBmb250LXNpemU9IjE0IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiI+Tm8gSW1hZ2U8L3RleHQ+PC9zdmc+';
  }
  return api.getImageUrl(props.session.id, photo, 'medium', 'webp');
});

const formatTime = (dateStr) => {
  const date = new Date(dateStr);
  return date.toLocaleTimeString('en-US', { 
    hour: 'numeric', 
    minute: '2-digit',
    hour12: true 
  });
};

const formatDuration = (seconds) => {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (mins > 0) {
    return `${mins}m ${secs}s`;
  }
  return `${secs}s`;
};

const handleImageError = (e) => {
  e.target.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iI2NjYyIvPjx0ZXh0IHRleHQtYW5jaG9yPSJtaWRkbGUiIHg9IjEwMCIgeT0iMTAwIiBmaWxsPSIjOTk5IiBmb250LXNpemU9IjE0IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiI+Tm8gSW1hZ2U8L3RleHQ+PC9zdmc+';
};
</script>

<style scoped>
.session-card {
  background: #000;
  border: 2px solid #c9302c;
  border-radius: 8px;
  overflow: hidden;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 2px 4px rgba(0,0,0,0.5);
}

.session-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(212, 175, 55, 0.3);
  border-color: #d4af37;
}

.session-card.selected {
  box-shadow: 0 0 0 3px #d4af37;
  border: 2px solid #d4af37;
}

.image-container {
  position: relative;
  aspect-ratio: 1;
  background: #f0f0f0;
  overflow: hidden;
}

.image-container img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.selected-badge {
  position: absolute;
  top: 10px;
  right: 10px;
  width: 30px;
  height: 30px;
  background: #d4af37;
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  font-size: 18px;
}

.session-info {
  padding: 15px;
  background: linear-gradient(to bottom, rgba(201, 48, 44, 0.1), rgba(0, 0, 0, 0.5));
}

.session-info h4 {
  margin: 0 0 8px 0;
  font-size: 1.1em;
  color: #d4af37;
  font-weight: bold;
  text-transform: uppercase;
}

.session-time {
  margin: 5px 0;
  color: #fff;
  font-size: 0.9em;
}

.session-stats {
  margin: 5px 0;
  color: #c9302c;
  font-size: 0.85em;
  font-weight: 600;
}
</style>