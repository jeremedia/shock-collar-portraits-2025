import express from 'express';
import cors from 'cors';
import compression from 'compression';
import path from 'path';
import { fileURLToPath } from 'url';
import config from './config.js';
import sessionsRouter from './routes/sessions.js';
import imagesRouter from './routes/images.js';
import selectionsRouter from './routes/selections.js';
import imageProcessor from './services/imageProcessor.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

app.use(cors({
  origin: config.corsOrigin,
  credentials: true
}));

app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/sessions', sessionsRouter);
app.use('/api/images', imagesRouter);
app.use('/api/selections', selectionsRouter);

app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    cache: config.cacheDir,
    photos: config.photosBaseDir
  });
});

if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../dist')));
  
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../dist', 'index.html'));
  });
}

setInterval(() => {
  imageProcessor.cleanCache();
}, 1000 * 60 * 60 * 24);

const server = app.listen(config.port, '0.0.0.0', () => {
  console.log(`Server running on port ${config.port} (all interfaces)`);
  console.log(`Photos directory: ${config.photosBaseDir}`);
  console.log(`Cache directory: ${config.cacheDir}`);
  
  if (process.env.NODE_ENV === 'production') {
    console.log(`Access the app at: http://localhost:${config.port}`);
  } else {
    console.log(`API server ready for development at: http://0.0.0.0:${config.port}`);
    console.log(`Network access: http://[your-ip]:${config.port}`);
  }
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

export default app;