# Thumbnail Variant & Caching Alignment Plan

## Goals
- Serve consistent thumbnail variants (thumb, face, portrait) on both heroes and gallery pages.
- Provide a single user-facing selector for thumbnail variant choice and persist it across pages.
- Ensure lazy-loading, caching, and navigation continue to work after the refactor.

## Tasks
1. **Shared Thumbnail Helper**
   - [ ] Create `HeroThumbnailSources` helper returning cached URLs for `thumb`, `face`, and `portrait` variants.
   - [ ] Use ActiveStorage variant or cached service method for portrait-sized crop (`portrait_thumb`).
   - [ ] Handle fallbacks when a variant is unavailable and log failures.

2. **Unify Card Markup**
   - [ ] Update `gallery/_session_card.html.erb` to include a single `<img>` with data attributes for all variants.
   - [ ] Replace hero index inline variant logic with helper usage.
   - [ ] Bump/rename relevant fragment caches to avoid serving old HTML.

3. **Enhance `thumbnail_size_controller`**
   - [ ] Replace "Faces Only" toggle with variant dropdown used on both pages.
   - [ ] Store variant choice under a shared key (e.g., `heroThumbnail.variant`).
   - [ ] Update controller to swap image sources, adjust CSS classes, and call into lazy loader.

4. **Lazy Image Integration**
   - [ ] Extend `lazy_images_controller` with a public `swap(src)` method, reusing IntersectionObserver when needed.
   - [ ] Allow thumbnail controller to trigger reloads for images already on screen.

5. **Portrait Variant Preprocessing**
   - [ ] Ensure portrait thumbnail variant is generated/stored; update jobs (`VariantGenerationJob`) if necessary.

6. **Navigation & Persistence Review**
   - [ ] Confirm `heroVisibleHeroes` still reflects filtered order after variant changes.
   - [ ] Document/namespace localStorage keys and clear stale data when filters reset.

7. **Testing & Cache Invalidation**
   - [ ] Clear Rails fragment cache keys impacted by new markup.
   - [ ] Smoke-test hero and gallery pages (size slider, variant selector, filters, navigation, lazy loading).

## Deliverables
- Updated helper, controllers, and views supporting unified variant selection.
- Migration or job updates for portrait variant generation.
- Manual test checklist results.

