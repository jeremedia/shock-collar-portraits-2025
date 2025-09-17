// Register Stimulus controllers explicitly (importmap has no globbing)
import { application } from "controllers/application"

import AdminEditorController from "controllers/admin_editor_controller"
import AdminTaggerController from "controllers/admin_tagger_controller"
import CollapsibleController from "controllers/collapsible_controller"
import DayAccordionController from "controllers/day_accordion_controller"
import FaceGridBackgroundController from "controllers/face_grid_background_controller"
import FlashController from "controllers/flash_controller"
import HelloController from "controllers/hello_controller"
import HeroFilterController from "controllers/hero_filter_controller"
import HeroImageController from "controllers/hero_image_controller"
import ImagePreloaderController from "controllers/image_preloader_controller"
import ImageViewerController from "controllers/image_viewer_controller"
import LazyImagesController from "controllers/lazy_images_controller"
import PreloaderScreenController from "controllers/preloader_screen_controller"
import QueueStatusController from "controllers/queue_status_controller"
import StatsController from "controllers/stats_controller"
import SwipeNavigationController from "controllers/swipe_navigation_controller"
import ThumbnailSizeController from "controllers/thumbnail_size_controller"

application.register("admin-editor", AdminEditorController)
application.register("admin-tagger", AdminTaggerController)
application.register("collapsible", CollapsibleController)
application.register("day-accordion", DayAccordionController)
application.register("face-grid-background", FaceGridBackgroundController)
application.register("flash", FlashController)
application.register("hello", HelloController)
application.register("hero-filter", HeroFilterController)
application.register("hero-image", HeroImageController)
application.register("image-preloader", ImagePreloaderController)
application.register("image-viewer", ImageViewerController)
application.register("lazy-images", LazyImagesController)
application.register("preloader-screen", PreloaderScreenController)
application.register("queue-status", QueueStatusController)
application.register("stats", StatsController)
application.register("swipe-navigation", SwipeNavigationController)
application.register("thumbnail-size", ThumbnailSizeController)
