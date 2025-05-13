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
    @GestureState private var magnification: CGFloat = .zero
    
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
        .rotation3DEffect(viewRotationY, axis: (x: 0, y: 1, z: 0))
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

/// **Order Matters With Gestures**
///
/// The order of the gestures matters, as they are attached to the RealityView.
///
/// The reason why order matters is that some gestures can be considered part of other gestures.
/// For instance, if you add a drag gesture for an entity followed by a tap gesture for that same
/// entity, it won't probably work the way you expect.
/// The drag gesture will capture the tap as part of recognizing the drag gesture, meaning that the
/// tap actions will go unexecuted or be executed at weird times.
///
/// ** Rotation With Drag Along the X-axis **
///
/// In our example above, dragging left or right on the earth causes it to spin around the Y-axis.
/// In this implementation, we need some math to know whether we are dragging left or right.
///
/// In order to know whether you are dragging left or right you need to keep track of:
///
/// 1. `entityDragLastLocation.x`: Where you _were_ along the x-axis.
///
/// 2. `entity.location.x`: Where you _are_ along the x-axis.
///
/// In other word, each frame, you need to keep track of the `deltaXTranslation = entity.location.x - entityDragLastLocation`.
///
/// We add two new @State variable within the view's scope:
///
/// ```swift
/// @State var private earthRotationY: Angle = .zero
/// @State var private earthLastDragLocation: CGPoint = .zero
/// ```
///
/// `earthRotationY` tracks the current number of degrees the earth is rotated, and it's initialized to 0 degrees.
///
/// With `earthDragLastLocation`, you store a (x, y, z) point representing the position of where the drag gesture last ended.
///
/// Let's implement the following code to have this work. Supposing that the entity we want to rotate is the `earth` entity.
///
/// ```swift
/// .gesture(
///     DragGesture()
///         .targetedToEntity(earth)
///         .onChanged { value in
///             var deltaXDrag = value.location.x - earthDragLastLocation
///
///             if (earth.position(relativeTo: nil).x > 0) {
///                 deltaXDrag = -deltaXDrag
///             }
///
///             if deltaXDrag > 0 {
///                 earthRotationY += .degrees(5.0)
///             }
///
///             if deltaXDrag < 0 {
///                 earthRotationY -= .degrees(5.0)
///             }
///
///             earthDragLastLocation = value.location
///
///             earth.orientation = simd_quatf(
///                 angle: Float(earthRotationY.radians),
///                 axis: SIMD<Float>(0, 1, 0)
///             )
///         }
/// )
/// ```
///
/// As you notice, the gesture is targeted to the `earth` entity.
/// As per its drag gesture, we need to write our code in the body of the function that gets passed to the
/// `onChanged()` method/event, since, in the `onChanged` event gesture modifier, its passed-over closure gets
/// executed upon recognizing the user's drag movement per frame. That gives you the ability to animate and change
/// directions before the gesture has even finished.
///
/// We then create an `deltaXDrag`, which represents the amount of change in the x coordinate from the current drag location
/// `value.location.x` to the previous location `earthDragLastLocation.x` (which is initialized to 0).
///
/// The current location of the drag is accessed via the `value` parameter provided to the action.
///
/// If you drag to the right, `deltaXDrag` is always positive (a larger number minus a smaller number); however, when
/// dragging to the left, `deltaXDrag` is always negative (a smaller number minus a larger number).
///
/// Keep in mind that those numbers are relative to the earth entity itself.
///
/// We then use two if statements to check to see if `deltaXDrag` is positive, and if so, we increment `earthRotationY.degrees`
/// by 5.0. If `deltaXDrag` is negative, we decrement `earthRotationY.degrees` by 5.0.
///
/// Once completed, we obviously update `earthDragLastLocation` to be the current drag location (value.location), since we
/// want to make sure that `deltaXDrag` is always representing the change with respect to the user's last drag location, instead
/// of relying on a static reference point. That makes sure that we dynamically keep track of the change in x and it's the most
/// accurate delta possible.
///
/// However, an interesting part of the code is the following:
///
/// if (earth.position(relativeTo: nil).x > 0) {
///     deltaXChange = -deltaXChange
/// }
///
/// That code above takes into account the situation in which we are rotating the entire RealityView around the Y axis.
/// In such a case, the earth might end up on the right side of the sun (the center of the RealityView's rotation).
///
/// That keeps track of whether the position of the `earth` entity is in the quadrant of the positive x's with
/// respect to the frame of reference of the immersive space/Volumetric Window (relativeTo: nil). If so, it means that
/// the `earth` entity's local frame of reference is now rotated around the Y axis, which also means that the positive direction
/// which the X axis is pointing towards got inverted. That entails the value of the drag amount being negative when dragging
/// to the right, and positive when dragging to the left.
///
/// In such a situation, we need to negate the `deltaXChange` to keep that X axis inversion into account (`deltaXChange = -deltaXChange`); that way, the comparison still works — even with the entire RealityView reversed.
///
/// **Note:** The earth rotation in response to the drag gesture still works when the earth is scaled; using the
/// properties on the `transform` object doesn't reset any other properties you've set.
///
///
/// RealityView Rotation with Drag
///
/// When it comes to rotating the RealityView when dragging the entity positioned at its center, there's no need to check
/// whether same entity's position relative to the view to see if its position got reversed with respect to the view's center.
/// That's because that entity is positioned at the center of the view itself, and a rotation of the view itself won't affect it.
///
/// We require the `minimumDistance` parameter's value of the `DragGesture` — upon its initialization — to be 1.0, to avoid
/// accidental drag recognition.
///
/// Additionally, a `coordinateSpace` parameter is set to `.global` (the default is `.local`).
/// This forces the gesture to be considered with respect to the global coordinate space (frame of reference) at the root of
/// the view hierarchy.
///
/// If you were to leave out the `coordinateSpace` parameter — which means to set it to the `.local` default — the gesture
/// will be considered with respect to the local frame of reference, which is the coordinate space of the entity itself.
/// In our example, the sun scene's coordinate system. However, because the sun scene's coordinate system itself is changing,
/// you would have that, each time, the x component of the position vector for the drag's location will then start changing
/// as well, since the position vector keeps getting expressed with respect to a changing coordinate system; precisely, the
/// vector's x component will start decreasing as the angle grows above zero degrees, you will then have a negative deltaX,
/// which will, in turn, as you keep dragging, increase the vector's x component back by a slight value
/// causing a positive deltaX, which will, again, decrease the vector's x component, and you'll get into a loop as you keep
/// dragging, which will make your rotation blocked.
///
/// However, by expressing the vector position for the drag location with respect to the global coordinate system, which does
/// not vary, you avoid this problem.
