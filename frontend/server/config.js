import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default {
  port: process.env.PORT || 3001,
  photosBaseDir: path.resolve(__dirname, '../../'), // Base directory for all photos
  cacheDir: path.resolve(__dirname, './cache'),
  thumbnailSizes: {
    small: { width: 200, height: 200 },
    medium: { width: 400, height: 400 },
    large: { width: 800, height: 800 },
    hero: { width: 1200, height: 1200 }
  },
  imageQuality: {
    webp: 85,
    jpeg: 90
  },
  corsOrigin: process.env.NODE_ENV === 'production' 
    ? ['http://localhost:5173', 'http://localhost:3000']
    : true, // Allow all origins in development
  maxConcurrentProcessing: 4,
  cacheMaxAge: 86400 * 30
};