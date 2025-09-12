# 📧 Email Collection System for Shock Collar Portraits

## Overview
Complete email collection system integrated with the photo gallery for gathering participant emails during or after photo sessions.

## Features

### 1. Dedicated Email Collector View (`/emails`)
- **Quick Entry Form**: Optimized for iPhone use during sessions
- **Auto-incrementing Session Numbers**: Automatically suggests next session number
- **Real-time Confirmation**: Shows last saved entry for 3 seconds
- **Recent Entries List**: View and manage last 20 entries
- **Import/Export**: Handle bulk data operations

### 2. In-Session Email Collection
- **Integrated in Session Viewer**: Add emails while showing photos to participants
- **Visual Feedback**: Shows if email already collected for session
- **Edit Capability**: Update existing email entries
- **Auto-save**: Persists to localStorage immediately

### 3. Data Management
- **Import from Markdown**: Process existing email lists
- **Export for Mail Merge**: Name,Email format for bulk mailing
- **Export as CSV**: Full data with timestamps and notes
- **JSON Export**: Complete backup with all metadata

## Usage Workflows

### During Photo Session (iPhone)
1. Open browser to `http://100.97.169.52:5173/emails`
2. After each portrait session:
   - Enter participant's name (optional)
   - Enter email address (required)
   - Session number auto-increments
   - Tap "Save & Next"
3. Continue with next participant

### While Reviewing Photos (iPad)
1. Open session in gallery viewer
2. Click "📧 Add Email" button below hero selection
3. Enter participant's details
4. Save and continue browsing

### Importing Existing Data
1. Navigate to Email Collector
2. Click "📥 Import" button
3. Paste email data (JSON or list format)
4. Click "Process Import"

## Data Structure

Emails are stored with:
- **Session ID**: Links to photo session
- **Name**: Participant's name (optional)
- **Email**: Email address (required)
- **Session Number**: Numeric identifier
- **Notes**: Additional context
- **Timestamp**: When collected

## Import Formats Supported

### JSON Format
```json
{
  "emails": {
    "burst_001_imported": {
      "name": "John Doe",
      "email": "john@example.com",
      "sessionNumber": 1
    }
  }
}
```

### List Formats
- `1. Name - email@domain.com`
- `Name [email@domain.com]`
- `email@domain.com`
- Checkbox format: `- [ ] email@domain.com`

## Existing Data Import

Already processed 181 emails from your markdown file:
- Monday: 54 emails
- Tuesday: 64 emails  
- Wednesday: 63 emails

To import these into the system:
1. Go to `/emails`
2. Click Import
3. Copy contents of `email_import.json`
4. Paste and process

## Access Points

- **Gallery Header**: 📧 Emails button
- **Session Viewer**: Email form below image controls
- **Direct URL**: `/emails`

## Storage

- **Primary**: localStorage (`shock_collar_emails`)
- **Backup**: Export to JSON/CSV
- **Persistence**: Survives browser refresh
- **Cross-session**: Available in all views

## Technical Implementation

- **Pinia Store**: Centralized email state management
- **Vue Components**: Reactive UI updates
- **Auto-save**: Every change persisted immediately
- **Validation**: Email format checking
- **Mobile Optimized**: Touch-friendly, no-zoom inputs

## Export Options

### Mail Merge CSV
Perfect for bulk email services:
```csv
Name,Email
Kevin Byrne,kevin@byrne.io
Angie Newton,Anewton1027@gmail.com
```

### Full Data CSV
Complete records with metadata:
```csv
Session,Name,Email,Notes,Timestamp
1,"Kevin Byrne","kevin@byrne.io","Imported from monday","2025-08-28T01:04:43.780Z"
```

## Best Practices

1. **During Sessions**: Use quick entry on iPhone for speed
2. **Post-Session**: Review and add missing emails via session viewer
3. **Daily Backup**: Export data at end of each day
4. **Name Collection**: Optional but helpful for personalization
5. **Session Linking**: Ensures emails match photo sessions

## Troubleshooting

### Emails Not Saving
- Check browser localStorage isn't full
- Verify email format is valid
- Try export/import to refresh

### Import Failing
- Ensure valid JSON format
- Check for duplicate session IDs
- Verify email addresses are valid

### Missing Emails
- Check "Recent Entries" in collector
- Use browser console: `localStorage.getItem('shock_collar_emails')`
- Restore from daily export backup

## Quick Commands

```bash
# Generate import file from markdown
node server/scripts/importEmails.js

# View stored emails in console
JSON.parse(localStorage.getItem('shock_collar_emails'))

# Clear all emails (careful!)
localStorage.removeItem('shock_collar_emails')
```

---

The email collection system seamlessly integrates with your photo workflow, ensuring no participant leaves without their contact info being captured for post-event gallery sharing.