//
//  ContentView.swift
//  TouchyVolumes
//
//  Created by Saverio Negro on 10/05/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    
    // Declare the entities in the struct's global scope to get access to them from anywhere
    // within the struct itself — mostly because of tapping into their transform upon a
    // specific gesture taking place.
    @State private var earth: Entity = Entity()
    @State private var moon: Entity = Entity()
    @State private var sun: Entity = Entity()
    @State private var sunAnimated = false
    @State private var earthRotationY: Angle = .zero
    @State private var earthDragLastLocation: CGPoint = .zero
    @State private var moonRotationY: Angle = .zero
    @State private var moonDragLastLocation: CGPoint = .zero
    @State private var viewRotationY: Angle = .zero
    @State private var viewDragLastLocation: CGPoint = .zero
    @GestureState private var addPlanet: Bool = false
    
    var body: some View {
        RealityView { content in
            
            // Load in sun entity and set its components to prepare the entity for interaction
            if let sunEntity = try? await Entity(named: "Sun", in: realityKitContentBundle) {
                
                self.sun = sunEntity
                self.sun.generateCollisionShapes(recursive: true)
                self.sun.components.set(InputTargetComponent())
                content.add(sun)
            }
            
            // Load in earth entity and set its components to prepare the entity for interaction
            if let earthEntity = try? await Entity(named: "Earth", in: realityKitContentBundle) {
                
                self.earth = earthEntity
                self.earth.generateCollisionShapes(recursive: true)
                self.earth.components.set(InputTargetComponent())
                self.earth.position.x = -0.3
                content.add(earth)
            }
            
            // Load in moon entity and set its components to prepare the entity for interaction
            if let moonEntity = try? await Entity(named: "Moon", in: realityKitContentBundle) {
                
                self.moon = moonEntity
                self.moon.generateCollisionShapes(recursive: true)
                self.moon.components.set(InputTargetComponent())
                self.moon.position.x = 0.3
                content.add(moon)
            }
            
        } update: { content in
            // Update content
            if addPlanet {
                addRandomPlanet(content: content)
            }
        }
        .gesture(
            TapGesture()
                .targetedToEntity(sun)
                .onEnded { _ in
                    
                    sunAnimated.toggle()
                    
                    Task {
                        if sunAnimated {
                            await setSunShader(maximumSize: .float(5.0), speed: .float(0.5))
                        } else {
                            await setSunShader(maximumSize: .float(0.0), speed: .float(1.0))
                        }
                    }
                }
        )
        .gesture(
            TapGesture(count: 2)
                .targetedToEntity(earth)
                .onEnded { _ in
                    scaleEntity(entity: earth)
                }
            )
        .gesture(
            DragGesture()
                .targetedToEntity(earth)
                .onChanged { value in
                    var deltaXDrag = value.location.x - earthDragLastLocation.x
                    
                    if (earth.position(relativeTo: nil).x > 0) {
                        deltaXDrag = -deltaXDrag
                    }
                    
                    if deltaXDrag > 0 {
                        earthRotationY += .degrees(5)
                    }
                    
                    if deltaXDrag < 0 {
                        earthRotationY -= .degrees(5)
                    }
                    
                    earthDragLastLocation = value.location
                    earth.orientation = .init(angle: Float(earthRotationY.radians), axis: [0, 1, 0])
                }
        )
        .gesture(
            DragGesture()
                .targetedToEntity(moon)
                .onChanged { value in
                    var deltaXDrag = value.location.x - moonDragLastLocation.x
                    
                    if (moon.position(relativeTo: nil).x < 0) {
                        deltaXDrag = -deltaXDrag
                    }
                    
                    if deltaXDrag > 0 {
                        moonRotationY += .degrees(5.0)
                    }
                    
                    if deltaXDrag < 0 {
                        moonRotationY -= .degrees(5.0)
                    }
                    
                    moonDragLastLocation = value.location
                    moon.orientation = simd_quatf(
                        angle: Float(moonRotationY.radians),
                        axis: SIMD3<Float>(0, 1, 0)
                    )
                }
        )
        .gesture(
            DragGesture(minimumDistance: 1.0, coordinateSpace: .global)
                .targetedToEntity(sun)
                .onChanged { value in
                    let deltaXDrag = value.location.x - viewDragLastLocation.x
                    
                    if deltaXDrag > 0 {
                        viewRotationY += .degrees(5.0)
                    }
                    
                    if deltaXDrag < 0 {
                        viewRotationY -= .degrees(5.0)
                    }
                    
                    viewDragLastLocation = value.location
                }
        )
        .gesture(
            MagnifyGesture()
                .targetedToEntity(moon)
                .onChanged { value in
                    
                    let magnificationFactor = Float(value.magnification)
                    
                    moon.transform.scale = SIMD3<Float>(
                        magnificationFactor,
                        magnificationFactor,
                        magnificationFactor
                    )
                }
        )
        .gesture(
            LongPressGesture(minimumDuration: 1.0, maximumDistance: 100)
                .targetedToAnyEntity()
                .updating($addPlanet) { value, gestureState, transaction in
                    gestureState = value.gestureValue
                }
        )
        .rotation3DEffect(viewRotationY, axis: (x: 0, y: 1, z: 0))
    }
    
    private func getRandomColor() -> UIColor {
        let red = CGFloat.random(in: 0...1)
        let green = CGFloat.random(in: 0...1)
        let blue = CGFloat.random(in: 0...1)
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    private func addRandomPlanet(content: RealityViewContent) {
        let randomRadius = Float.random(in: 0.007...0.04)
        let sphere = ModelEntity(mesh: .generateSphere(radius: randomRadius))
        
        let randomRoughness = Float.random(in: 0...1)
        let material = SimpleMaterial(
            color: getRandomColor(),
            roughness: MaterialScalarParameter.float(randomRoughness),
            isMetallic: Bool.random()
        )
        sphere.model?.materials = [material]
        sphere.position.x = Float.random(in: -0.4...0.4)
        sphere.position.y = Float.random(in: -0.4...0.4)
        sphere.position.z = Float.random(in: 0.1...0.4)
        sphere.generateCollisionShapes(recursive: true)
        sphere.components.set(InputTargetComponent())
        content.add(sphere)
    }
    
    private func scaleEntity(entity: Entity) {
        
        switch entity.scale {
        case [1.0, 1.0, 1.0]:
            entity.scale = [1.5, 1.5, 1.5]
        case [1.5, 1.5, 1.5]:
            entity.scale = [1.75, 1.75, 1.75]
        default:
            entity.scale = [1.0, 1.0, 1.0]
        }
    }
    
    private func setSunShader(maximumSize: MaterialParameters.Value, speed: MaterialParameters.Value) async {
        guard
            var sunShader = try? await ShaderGraphMaterial(
                named: "/Root/Pulse_Modifier",
                from: "Sun.usda",
                in: realityKitContentBundle
            )
        else {
            return
        }
        
        do {
            try sunShader.setParameter(name: "MaximumSize", value: maximumSize)
            try sunShader.setParameter(name: "Speed", value: speed)
        } catch {
            fatalError("Failed setting parameters to shader graph material: \(error.localizedDescription)")
        }
        
        guard let sunModel = sun.findEntity(named: "Sphere") as? ModelEntity else { return }
        sunModel.model?.materials = [sunShader]
    }
}
