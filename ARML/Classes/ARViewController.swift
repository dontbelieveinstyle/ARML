//
//  ARViewController.swift
//  ARML
//
//  Created by Gil Nakache on 28/01/2019.
//  Copyright © 2019 viseo. All rights reserved.
//

import ARKit

open class ARViewController: UIViewController, ARSessionDelegate, ARSCNViewDelegate {
    // MARK: - Variables

    private let sceneView = ARSCNView()
    private var currentBuffer: CVPixelBuffer?
    private let handDetector = HandDetector()
    private let previewView = UIImageView()

    // MARK: - Lifecycle

    open override func loadView() {
        super.loadView()

        view = sceneView

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Enable Horizontal plane detection
        configuration.planeDetection = .horizontal

        // Disabled because of random crash
        configuration.environmentTexturing = .none

        // The delegate is used to receive ARAnchors when they are detected.
        sceneView.delegate = self

        // We want to receive the frames from the video
        sceneView.session.delegate = self

        // Run the session with the configuration
        sceneView.session.run(configuration)

        view.addSubview(previewView)

        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewDidTap(recognizer:))))

        sceneView.autoenablesDefaultLighting = true

        // Add spotlight to cast shadows
        let spotlightNode = SpotlightNode()
        spotlightNode.position = SCNVector3(10, 10, 0)
        sceneView.scene.rootNode.addChildNode(spotlightNode)
    }

    // MARK: - Actions

    @objc private func viewDidTap(recognizer: UITapGestureRecognizer) {
        // We get the tap location as a 2D Screen coordinate
        let tapLocation = recognizer.location(in: sceneView)

        // To transform our 2D Screen coordinates to 3D screen coordinates we use hitTest function
        let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)

        // We cast a ray from the point tapped on screen, and we return any intersection with existing planes
        guard let hitTestResult = hitTestResults.first else { return }

        let ball = BallNode(radius: 0.05)

        // We place the ball at hit point
        ball.simdTransform = hitTestResult.worldTransform
        // We place it slightly (20cm) above the plane
        ball.position.y += 0.2

        // We add the node to the scene
        sceneView.scene.rootNode.addChildNode(ball)
    }

    // MARK: - ARSessionDelegate

    open func session(_: ARSession, didUpdate frame: ARFrame) {
        // We return early if currentBuffer is not nil or the tracking state of camera is not normal
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
            return
        }

        // Retain the image buffer for Vision processing.
        currentBuffer = frame.capturedImage

        startDetection()
    }

    // MARK: - Private functions

    private func startDetection() {
        // Here we will do our CoreML request on currentBuffer
        guard let someBuffer = currentBuffer else { return }

        handDetector.performDetection(inputBuffer: someBuffer) { outputPixelBuffer, _ in

            if let outputBuffer = outputPixelBuffer {

                DispatchQueue.main.async {
                    self.previewView.image = UIImage(ciImage: CIImage(cvPixelBuffer: outputBuffer))
                }

            }
            // Release currentBuffer to allow processing next frame
            self.currentBuffer = nil
        }
    }

    // MARK: - ARSCNViewDelegate

    public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let _ = anchor as? ARPlaneAnchor else { return nil }

        // We return a special type of SCNNode for ARPlaneAnchors
        return PlaneNode()
    }

    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node as? PlaneNode else {
                return
        }
        planeNode.update(from: planeAnchor)
    }

    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let planeNode = node as? PlaneNode else {
                return
        }
        planeNode.update(from: planeAnchor)
    }
}
