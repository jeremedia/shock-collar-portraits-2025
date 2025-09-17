# S3 CORS Configuration for Service Worker Caching

## Problem
When using direct S3 URLs (instead of Rails proxy), the service worker needs proper CORS headers to cache cross-origin resources. Without proper CORS configuration on the S3 bucket, the service worker will receive "opaque" responses that cannot be cached.

## Required S3 Bucket CORS Configuration

Add this CORS configuration to your S3 bucket (via AWS Console → S3 → Bucket → Permissions → CORS):

```json
[
    {
        "AllowedHeaders": [
            "*"
        ],
        "AllowedMethods": [
            "GET",
            "HEAD"
        ],
        "AllowedOrigins": [
            "http://localhost:*",
            "http://127.0.0.1:*",
            "https://scp-25.oknotok.com",
            "https://scp-25-dev.oknotok.com",
            "https://scp-dev.zice.app",
            "http://100.97.169.52:*",
            "http://192.168.*:*"
        ],
        "ExposeHeaders": [
            "ETag",
            "Content-Type",
            "Content-Length",
            "Cache-Control"
        ],
        "MaxAgeSeconds": 3600
    }
]
```

## AWS CLI Command
Alternatively, use the AWS CLI to set the CORS configuration:

```bash
aws s3api put-bucket-cors --bucket shock-collar-portraits-2025 --cors-configuration file://cors.json
```

Where `cors.json` contains the configuration above.

## How to Verify CORS is Working

1. Open browser DevTools → Network tab
2. Load a page with S3 images
3. Click on an S3 image request
4. Check Response Headers for:
   - `Access-Control-Allow-Origin: *` or your specific domain
   - `Access-Control-Expose-Headers: ...`

## Service Worker Behavior

### With Proper CORS:
- Response type: "cors"
- Can read response headers
- Can cache the response
- Console shows: "[SW] Cached: https://s3..."

### Without CORS (Opaque Response):
- Response type: "opaque"
- Cannot read response headers or body
- Service worker skips caching
- Console shows: "[SW] Skipping opaque response: https://s3..."

## Alternative: Use Rails Proxy

If CORS configuration is not possible, re-enable the Rails proxy by:

1. Uncomment in `config/application.rb`:
```ruby
config.active_storage.resolve_model_to_route = :rails_storage_proxy
```

2. Update helpers to use `rails_storage_proxy_url` instead of `rails_blob_url`

This routes images through Rails, avoiding CORS issues but with performance overhead.

## Testing the Service Worker

1. Clear cache: Open DevTools → Application → Storage → Clear site data
2. Reload page to register new service worker
3. Check console for caching messages
4. Go offline (DevTools → Network → Offline)
5. Reload page - cached images should still load

## Troubleshooting

### Images not caching:
- Check S3 CORS configuration
- Verify service worker version updated (check console)
- Clear browser cache and reload
- Check for "opaque" responses in console

### Service worker not updating:
- Hard reload: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)
- DevTools → Application → Service Workers → Update
- Clear all site data and reload

### CORS errors in console:
- Verify your domain is in AllowedOrigins
- Check S3 bucket policy allows public read
- Ensure Active Storage is generating correct S3 URLs