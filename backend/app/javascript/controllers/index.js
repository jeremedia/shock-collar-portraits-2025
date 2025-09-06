// Import and register all Stimulus controllers

import { application } from "controllers/application"

import CollapsibleController from "controllers/collapsible_controller"
application.register("collapsible", CollapsibleController)

import ImageViewerController from "controllers/image_viewer_controller"
application.register("image-viewer", ImageViewerController)