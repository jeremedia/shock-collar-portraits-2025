# ⚡ OKNOTOK Shock Collar Portraits - Quick Reference Guide

## 🚀 Starting the System
```bash
cd /Users/jeremy/Desktop/OK-SHOCK-25/shock-collar-vue
./start.sh
```
Then open: **http://100.97.169.52:5173** on iPad

## 📸 During Photo Sessions

### Camera Settings (Canon R5)
- Burst mode: High speed
- Focus: Continuous AF
- File: JPG (not RAW+JPG to save space)

### If Camera Overheats
- Switch to iPhone immediately
- Photos will integrate automatically
- Keep same burst timing pattern

## 🖥️ Operating the Gallery

### Key Functions
| Action | Method |
|--------|--------|
| **View Gallery** | Tap day headers to expand/collapse |
| **Set Hero Shot** | Spacebar or tap "Select as Hero" |
| **Next Photo** | Right arrow / Swipe left / Tap image |
| **Previous Photo** | Left arrow / Swipe right |
| **Next Session** | At last photo, press right arrow |
| **Export Selections** | Ctrl+S or 💾 button |
| **Slideshow Mode** | ▶ Slideshow button |

### iPad Gestures
- **Swipe horizontally**: Navigate photos
- **Tap session card**: Open session
- **Tap image**: Next photo
- **Touch controls**: Show/hide UI

## 👥 Showing Participants Their Photos

1. Find their session (look for approximate time)
2. Let them swipe through
3. Ask them to pick favorite
4. Tap "Select as Hero" on their choice
5. Their selection is auto-saved

## 🎬 Display Mode (While People Wait in Line)

1. Click "▶ Slideshow" button
2. Autoplay starts after 1 second
3. Shows only hero shots
4. Loops continuously
5. Tap to pause/show controls

## 🔧 Troubleshooting

### If Photos Don't Load
```bash
# Restart servers
Ctrl+C  # Stop current
./start.sh  # Start again
```

### If Selections Aren't Saving
1. Check localStorage in browser console
2. Use Export button to backup
3. Selections persist across restarts

### If New Photos Need Adding
1. Copy to appropriate directory
2. Run: `node server/scripts/buildIndex.js`
3. Refresh browser

## 📊 Current Stats
- **141 sessions** photographed
- **3,943 photos** total
- **~28 photos** per session average
- **All selections** backed up locally

## 🎯 Best Practices

### For Photo Sessions
- Take 20-40 photos per person
- Capture: anticipation → shock → reaction
- 30+ second gap = new session
- Keep camera USB connected

### For Gallery Display
- Keep iPad plugged in
- Use Guided Access to lock app
- Enable autoplay for ambient display
- Export selections daily for backup

## 🌟 Pro Tips

1. **Quick Review**: Use slideshow mode between sessions
2. **Batch Selection**: Review all at end of day
3. **Participant Choice**: Let them pick during downtime
4. **Social Sharing**: Export creates shareable list
5. **Performance**: Close other apps on Mac/iPad

## 📱 iPad Lock Screen (Guided Access)

1. Triple-click power button
2. Select Guided Access
3. Set passcode
4. Tap Start (top right)
5. To exit: Triple-click + passcode

---

**Remember**: Every shocked face tells a story of joyful boundary-pushing! ⚡

*May your captures be sharp and your reactions genuine!*

**OKNOTOK Camp - Burning Man 2025**