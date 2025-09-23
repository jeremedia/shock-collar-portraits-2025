# Production SSH Access Documentation

## Connection Details
- **Host**: `jer-serve`
- **User**: `jeremy`
- **Path**: `/home/jeremy/apps/shock-collar-portraits-2025`

## SSH Command
```bash
ssh jeremy@jer-serve
```

## Ruby Environment (RVM)
The production server uses RVM (Ruby Version Manager) with Ruby 3.4.5.

### Environment Variables
```bash
GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5
PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:$PATH
```

## Common Production Commands

### Rails Console
```bash
ssh jeremy@jer-serve "cd /home/jeremy/apps/shock-collar-portraits-2025 && GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5 PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:\$PATH RAILS_ENV=production bundle exec rails console"
```

### Rails Runner (for one-line commands)
```bash
ssh jeremy@jer-serve "cd /home/jeremy/apps/shock-collar-portraits-2025 && GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5 PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:\$PATH RAILS_ENV=production bundle exec rails runner 'YOUR_RUBY_CODE_HERE'"
```

## Example Production Queries

### Check Queue Status
```bash
ssh jeremy@jer-serve "cd /home/jeremy/apps/shock-collar-portraits-2025 && GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5 PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:\$PATH RAILS_ENV=production bundle exec rails runner 'puts SolidQueue::Job.where(finished_at: nil).count'"
```

### Check Failed Jobs
```bash
ssh jeremy@jer-serve "cd /home/jeremy/apps/shock-collar-portraits-2025 && GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5 PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:\$PATH RAILS_ENV=production bundle exec rails runner 'puts SolidQueue::FailedExecution.count'"
```

### Check Invitation Status
```bash
ssh jeremy@jer-serve "cd /home/jeremy/apps/shock-collar-portraits-2025 && GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5 PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:\$PATH RAILS_ENV=production bundle exec rails runner 'puts \"Pending: #{User.invitation_not_accepted.count}\"; puts \"Accepted: #{User.invitation_accepted.count}\"'"
```

### Check Email Configuration
```bash
ssh jeremy@jer-serve "cd /home/jeremy/apps/shock-collar-portraits-2025 && GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5 PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:\$PATH RAILS_ENV=production bundle exec rails runner 'puts Devise.mailer_sender'"
```

## Database Queries

### Count Photos
```bash
ssh jeremy@jer-serve "cd /home/jeremy/apps/shock-collar-portraits-2025 && GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5 PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:\$PATH RAILS_ENV=production bundle exec rails runner 'puts Photo.count'"
```

### Count Sessions
```bash
ssh jeremy@jer-serve "cd /home/jeremy/apps/shock-collar-portraits-2025 && GEM_HOME=/usr/share/rvm/gems/ruby-3.4.5 PATH=/usr/share/rvm/gems/ruby-3.4.5/bin:/usr/share/rvm/rubies/ruby-3.4.5/bin:\$PATH RAILS_ENV=production bundle exec rails runner 'puts PhotoSession.count'"
```

## Logs

### View Rails Log
```bash
ssh jeremy@jer-serve "tail -f /home/jeremy/apps/shock-collar-portraits-2025/log/production.log"
```

### Search Logs for Errors
```bash
ssh jeremy@jer-serve "grep -i error /home/jeremy/apps/shock-collar-portraits-2025/log/production.log | tail -20"
```

## Service Management (via systemd)

The application runs as a systemd service managed by Kamal/Docker.

### Check Service Status
```bash
ssh jeremy@jer-serve "docker ps | grep shock-collar"
```

## File Operations

### Copy Files to Production
```bash
scp local_file.rb jeremy@jer-serve:/home/jeremy/apps/shock-collar-portraits-2025/scripts/
```

### Copy Files from Production
```bash
scp jeremy@jer-serve:/home/jeremy/apps/shock-collar-portraits-2025/tmp/file.txt ./
```

## Important Notes

1. **Always use RAILS_ENV=production** for production commands
2. **RVM paths must be set** for Ruby commands to work
3. **The app path is** `/home/jeremy/apps/shock-collar-portraits-2025`
4. **Database is PostgreSQL** (not SQLite like development)
5. **Email sender is** `mrok@oknotok.com`

## Security Reminders

- SSH access is key-based (no password authentication)
- Production credentials are in Rails encrypted credentials
- Never commit production secrets to the repository
- Always test commands locally first when possible

## Troubleshooting

### Ruby Version Mismatch
If you see "Your Ruby version is X, but your Gemfile specified Y", ensure you're using the RVM environment variables shown above.

### Permission Issues
The application runs as the `jeremy` user. Ensure file permissions match when adding new files.

### Database Connection
Production uses PostgreSQL via DATABASE_URL environment variable configured in the deployment.

---

*Last Updated: September 2025*
*This documentation helps Claude Code efficiently access and diagnose production issues.*