import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// HEIC -> JPEG converter using CoreImage + ImageIO
// Usage: swift bin/convert_heic.swift /path/to/input.heic /path/to/output.jpg

func log(_ msg: String) {
  FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
}

guard CommandLine.arguments.count >= 3 else {
  log("Usage: swift convert_heic.swift <input.heic> <output.jpg>")
  exit(2)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)

do {
  // Load image honoring embedded orientation
  let options: [CIImageOption: Any] = [ .applyOrientationProperty: true ]
  guard let ciImage = CIImage(contentsOf: inputURL, options: options) else {
    log("Failed to load input image: \(inputPath)")
    exit(1)
  }

  let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
  let rect = ciImage.extent.integral
  guard let cg = context.createCGImage(ciImage, from: rect) else {
    log("Failed to render CGImage")
    exit(1)
  }

  // Write JPEG with quality ~95%
  guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
    log("Failed to create image destination")
    exit(1)
  }
  let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.95]
  CGImageDestinationAddImage(dest, cg, props as CFDictionary)
  if !CGImageDestinationFinalize(dest) {
    log("Failed to write output image")
    exit(1)
  }

  exit(0)
} catch {
  log("Conversion error: \(error.localizedDescription)")
  exit(1)
}

