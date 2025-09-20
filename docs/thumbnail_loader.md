# OKNOTOK Thumbnail Loader

The OKNOTOK thumbnail loader is a reusable overlay animation that appears while thumbnails are fetched or processed. It presents the camp-themed 🆗 / 🚫 cross-fade, along with an orbiting red comet that collapses once the asset finishes loading.

## Usage

Embed the loader inside any thumbnail container that is already using the `lazy-images` Stimulus controller:

```erb
<div class="thumbnail-container" data-controller="lazy-images">
  <%= image_tag ... %>
  <%= render "shared/thumbnail_loader" %>
</div>
```

The shared partial wires up the required markup and target attributes:

```erb
<%= render "shared/thumbnail_loader" %>
```

The loader automatically manages its state when the container dispatches these custom events:

- `thumbnail:loading` — starts a 1s delay before showing the animation.
- `thumbnail:loaded` — triggers the completion sequence and fade-out.

Both the `lazy_images_controller` and `thumbnail_size_controller` already emit these events. Controllers in other areas can adopt the same pattern to reuse the animation.

## Behavior

- **Deferred reveal**: the overlay only appears if loading exceeds one second.
- **Variant completion**: the orbit shrinks behind the 🆗 emoji as the new thumbnail fades in.
- **Graceful fade**: the loader cross-fades out while the image opacity returns to 1, avoiding abrupt cuts.

## Styling

Loader styles live in `app/assets/tailwind/application.css`. If you need to adjust colors or timing for another feature, prefer adding modifier classes around the shared partial rather than editing the base selectors.

