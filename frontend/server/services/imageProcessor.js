import sharp from 'sharp';
import fs from 'fs/promises';
import path from 'path';
import crypto from 'crypto';
import config from '../config.js';

class ImageProcessor {
  constructor() {
    this.processingQueue = [];
    this.processing = new Set();
    this.maxConcurrent = config.maxConcurrentProcessing;
  }

  async generateThumbnail(inputPath, size = 'medium', format = 'webp') {
    const sizeConfig = config.thumbnailSizes[size];
    if (!sizeConfig) {
      throw new Error(`Invalid size: ${size}`);
    }

    const hash = crypto
      .createHash('md5')
      .update(`${inputPath}-${size}-${format}`)
      .digest('hex');
    
    const cacheFileName = `${hash}_${size}.${format}`;
    const cachePath = path.join(config.cacheDir, cacheFileName);

    try {
      await fs.access(cachePath);
      return cachePath;
    } catch (error) {
    }

    await fs.mkdir(path.dirname(cachePath), { recursive: true });

    const quality = config.imageQuality[format] || 85;

    try {
      const pipeline = sharp(inputPath)
        .resize(sizeConfig.width, sizeConfig.height, {
          fit: 'inside',
          withoutEnlargement: true
        })
        .rotate();

      if (format === 'webp') {
        await pipeline.webp({ quality }).toFile(cachePath);
      } else if (format === 'jpeg' || format === 'jpg') {
        await pipeline.jpeg({ quality }).toFile(cachePath);
      } else {
        await pipeline.toFile(cachePath);
      }

      return cachePath;
    } catch (error) {
      console.error(`Error processing image ${inputPath}:`, error);
      throw error;
    }
  }

  async getImageMetadata(imagePath) {
    try {
      const metadata = await sharp(imagePath).metadata();
      return {
        width: metadata.width,
        height: metadata.height,
        format: metadata.format,
        orientation: metadata.orientation || 1,
        size: (await fs.stat(imagePath)).size
      };
    } catch (error) {
      console.error(`Error getting metadata for ${imagePath}:`, error);
      return null;
    }
  }

  async processWithQueue(inputPath, size, format) {
    const key = `${inputPath}-${size}-${format}`;
    
    if (this.processing.has(key)) {
      return new Promise((resolve, reject) => {
        this.processingQueue.push({ key, resolve, reject });
      });
    }

    if (this.processing.size >= this.maxConcurrent) {
      return new Promise((resolve, reject) => {
        this.processingQueue.push({ 
          key, 
          resolve, 
          reject,
          inputPath,
          size,
          format
        });
      });
    }

    this.processing.add(key);
    
    try {
      const result = await this.generateThumbnail(inputPath, size, format);
      this.processing.delete(key);
      this.processNext();
      return result;
    } catch (error) {
      this.processing.delete(key);
      this.processNext();
      throw error;
    }
  }

  processNext() {
    if (this.processingQueue.length === 0 || this.processing.size >= this.maxConcurrent) {
      return;
    }

    const next = this.processingQueue.shift();
    if (!next) return;

    this.processWithQueue(next.inputPath, next.size, next.format)
      .then(next.resolve)
      .catch(next.reject);
  }

  async cleanCache(maxAgeMs = config.cacheMaxAge * 1000) {
    try {
      const files = await fs.readdir(config.cacheDir);
      const now = Date.now();
      
      for (const file of files) {
        const filePath = path.join(config.cacheDir, file);
        const stats = await fs.stat(filePath);
        
        if (now - stats.mtimeMs > maxAgeMs) {
          await fs.unlink(filePath);
        }
      }
    } catch (error) {
      console.error('Error cleaning cache:', error);
    }
  }
}

export default new ImageProcessor();