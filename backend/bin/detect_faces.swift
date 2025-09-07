#!/usr/bin/env swift

import Vision
import CoreImage
import Foundation
import ImageIO

// Face detection script using macOS Vision framework
// Usage: swift detect_faces.swift /path/to/image.jpg

struct FaceData: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let confidence: Float
    let hasSmile: Bool?
    let leftEyeClosed: Bool?
    let rightEyeClosed: Bool?
}

struct DetectionResult: Codable {
    let success: Bool
    let imageWidth: Int
    let imageHeight: Int
    let faces: [FaceData]
    let error: String?
}

func detectFaces(imagePath: String) {
    let fileURL = URL(fileURLWithPath: imagePath)
    
    // Load image and get dimensions, respecting EXIF orientation
    guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
        let result = DetectionResult(success: false, imageWidth: 0, imageHeight: 0, faces: [], error: "Failed to load image")
        outputJSON(result)
        return
    }
    
    // Create options to respect orientation
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 4000
    ]
    
    guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
        let result = DetectionResult(success: false, imageWidth: 0, imageHeight: 0, faces: [], error: "Failed to create oriented image")
        outputJSON(result)
        return
    }
    
    let imageWidth = image.width
    let imageHeight = image.height
    
    // Create face detection request with landmarks and classification
    let request = VNDetectFaceRectanglesRequest { request, error in
        if let error = error {
            let result = DetectionResult(success: false, imageWidth: imageWidth, imageHeight: imageHeight, faces: [], error: error.localizedDescription)
            outputJSON(result)
            return
        }
        
        guard let observations = request.results as? [VNFaceObservation] else {
            let result = DetectionResult(success: true, imageWidth: imageWidth, imageHeight: imageHeight, faces: [], error: nil)
            outputJSON(result)
            return
        }
        
        // Convert Vision coordinates (normalized, bottom-left origin) to image coordinates (top-left origin)
        let faces = observations.map { observation -> FaceData in
            let boundingBox = observation.boundingBox
            
            // Vision uses normalized coordinates (0-1) with origin at bottom-left
            // Convert to pixel coordinates with origin at top-left
            let x = boundingBox.origin.x * Double(imageWidth)
            let y = Double(imageHeight) - (boundingBox.origin.y + boundingBox.height) * Double(imageHeight)
            let width = boundingBox.width * Double(imageWidth)
            let height = boundingBox.height * Double(imageHeight)
            
            return FaceData(
                x: x,
                y: y,
                width: width,
                height: height,
                confidence: observation.confidence,
                hasSmile: nil,
                leftEyeClosed: nil,
                rightEyeClosed: nil
            )
        }
        
        let result = DetectionResult(success: true, imageWidth: imageWidth, imageHeight: imageHeight, faces: faces, error: nil)
        outputJSON(result)
    }
    
    // Configure request for better accuracy
    request.revision = VNDetectFaceRectanglesRequestRevision3
    
    // Create handler and perform request
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    
    do {
        try handler.perform([request])
    } catch {
        let result = DetectionResult(success: false, imageWidth: imageWidth, imageHeight: imageHeight, faces: [], error: error.localizedDescription)
        outputJSON(result)
    }
}

func outputJSON(_ result: DetectionResult) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    
    if let jsonData = try? encoder.encode(result),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
    } else {
        print("{\"success\": false, \"error\": \"Failed to encode JSON\"}")
    }
}

// Main execution
guard CommandLine.arguments.count > 1 else {
    print("{\"success\": false, \"error\": \"Usage: detect_faces.swift /path/to/image.jpg\"}")
    exit(1)
}

let imagePath = CommandLine.arguments[1]

// Check if file exists
if !FileManager.default.fileExists(atPath: imagePath) {
    print("{\"success\": false, \"error\": \"File not found: \(imagePath)\"}")
    exit(1)
}

detectFaces(imagePath: imagePath)