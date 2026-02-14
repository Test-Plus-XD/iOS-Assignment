Here is a comprehensive usage specification for **Liquid Glass** in **SwiftUI** (introduced with iOS 26, iPadOS 26, macOS Tahoe, etc., in 2025), based on Apple's official developer documentation, WWDC 2025 sessions, and sample code patterns.

This guide covers the main APIs, configuration options, best practices, common patterns, and many practical code examples.

### Overview

**Liquid Glass** is a dynamic, translucent material that combines glass-like optical properties (blur, reflection, refraction) with fluid, organic behavior. It responds to:

- Content behind it
- User interaction (touch, hover, focus)
- Environment (light/dark mode, ambient lighting)
- Overlap with other glass elements

It is **not** a simple blur — it is a full material system designed to create a clear functional layer (controls, navigation) above content.

### Core Components

| Component                  | Purpose                                                                 | Availability     |
|----------------------------|-------------------------------------------------------------------------|------------------|
| `Glass`                    | Configuration struct for the material (variant, tint, interactivity)   | iOS 26+          |
| `.glassEffect()`           | Main view modifier to apply Liquid Glass                               | iOS 26+          |
| `GlassEffectContainer`     | Groups multiple glass effects for correct blending & morphing          | iOS 26+          |
| `.glassEffectID()`         | Assigns identity for smooth morphing animations during transitions     | iOS 26+          |
| `.interactive()`           | Enables touch/hover response (scale, bounce, shimmer)                  | iOS 26+          |

### The `Glass` Structure

`Glass` is a value type that defines the appearance and behavior.

**Main variants**:

```swift
extension Glass {
    static var regular: Glass        // Default — balanced translucency
    static var clear: Glass          // Very transparent, subtle
    static var identity: Glass       // Minimal effect — useful for conditional states
}
```

**Common configuration methods**:

```swift
let glass = Glass.regular
    .tint(.purple.opacity(0.4))     // Optional tint
    .interactive(true)              // Enables physics-based response
```

### 1. Basic `.glassEffect()` Usage

The simplest way to apply Liquid Glass:

```swift
import SwiftUI

struct BasicExample: View {
    var body: some View {
        Text("Hello, Liquid Glass!")
            .font(.title)
            .padding()
            .glassEffect()                    // Uses .regular + Capsule by default
    }
}
```

**Custom shape**:

```swift
Text("Rounded Rectangle Glass")
    .font(.title2)
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
    .glassEffect(in: .rect(cornerRadius: 16))
```

**Custom Glass configuration**:

```swift
Text("Tinted & Interactive")
    .font(.headline)
    .padding()
    .glassEffect(
        Glass.regular
            .tint(.blue.opacity(0.25))
            .interactive(true)
    )
```

### 2. Combining Multiple Glass Elements (GlassEffectContainer)

When multiple glass views overlap or transition, wrap them in `GlassEffectContainer` for correct blending and morphing.

```swift
struct ButtonGroup: View {
    @State private var selected = 0
    
    var body: some View {
        GlassEffectContainer(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Button("Option \(index + 1)") {
                    selected = index
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassEffect(
                    Glass.regular
                        .interactive(true)
                )
                .glassEffectID("option-\(index)")   // Enables morphing
                .opacity(selected == index ? 1 : 0.7)
            }
        }
        .padding()
    }
}
```

### 3. Morphing / Transition Effects

Use `.glassEffectID()` + `GlassEffectContainer` + transitions:

```swift
struct MorphingTabs: View {
    @Namespace private var namespace
    @State private var selectedTab = "Home"
    
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                TabButton(title: "Home", selected: selectedTab == "Home")
                    .glassEffectID("tab-home", in: namespace)
                
                TabButton(title: "Search", selected: selectedTab == "Search")
                    .glassEffectID("tab-search", in: namespace)
                
                TabButton(title: "Profile", selected: selectedTab == "Profile")
                    .glassEffectID("tab-profile", in: namespace)
            }
            .padding(6)
            .background(.ultraThinMaterial) // Optional — combines well
        }
        .padding()
    }
    
    @ViewBuilder
    func TabButton(title: String, selected: Bool) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .glassEffect(
                selected ? .regular.interactive() : .clear
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = title
                }
            }
    }
}
```

The `glassEffectID` allows SwiftUI to animate the glass shape fluidly from one tab to another.

### 4. Interactive vs Non-Interactive

Interactive glass reacts to touch/hover with subtle scale, bounce, and shimmer:

```swift
Button("Press Me") {
    // action
}
.buttonStyle(.plain)
.padding()
.glassEffect(.regular.interactive())
```

Non-interactive (static, clean look):

```swift
.glassEffect(.regular)                    // no interaction response
```

### 5. Conditional Application (iOS 26+ compatibility)

```swift
extension View {
    @ViewBuilder
    func glassEffectIfAvailable(
        _ glass: Glass = .regular,
        in shape: some Shape = Capsule()
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(glass, in: shape)
        } else {
            self.background(.ultraThinMaterial) // fallback
        }
    }
}

// Usage:
Text("Modern Glass")
    .padding()
    .glassEffectIfAvailable(.regular.interactive())
```

### 6. Best Practices & Guidelines (from HIG & WWDC)

- **Use sparingly** — mainly for controls, navigation, transient UI
- **Avoid on content backgrounds** — use standard materials instead
- **Prefer system components** — toolbars, tab bars, sheets automatically adopt Liquid Glass
- **Group related glass elements** — always use `GlassEffectContainer` when combining
- **Use `.interactive()`** for buttons, sliders, toggles, etc.
- **Respect accessibility** — Liquid Glass respects "Reduce Transparency"
- **Performance** — combining effects in a container is more efficient than many separate applications

### 7. Realistic Example — Floating Action Button Group

```swift
struct FloatingControls: View {
    @State private var isExpanded = false
    
    var body: some View {
        GlassEffectContainer(spacing: 12) {
            if isExpanded {
                ActionButton(icon: "square.and.arrow.up", label: "Share")
                    .glassEffectID("share", in: namespace)
                
                ActionButton(icon: "bookmark", label: "Save")
                    .glassEffectID("save", in: namespace)
                
                ActionButton(icon: "heart", label: "Favorite")
                    .glassEffectID("favorite", in: namespace)
            }
            
            MainFAB(isExpanded: $isExpanded)
                .glassEffectID("main", in: namespace)
        }
        .padding()
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isExpanded)
    }
    
    @Namespace private var namespace
    
    @ViewBuilder
    func ActionButton(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
            Text(label)
                .font(.caption)
        }
        .padding()
        .glassEffect(.regular.interactive())
    }
    
    @ViewBuilder
    func MainFAB(isExpanded: Binding<Bool>) -> some View {
        Button {
            isExpanded.wrappedValue.toggle()
        } label: {
            Image(systemName: isExpanded.wrappedValue ? "xmark" : "plus")
                .font(.title)
                .padding(20)
        }
        .glassEffect(.regular.interactive())
    }
}
```

### Summary Table — Most Common Patterns

| Goal                              | Recommended Pattern                                  | Key Modifiers / Containers                 |
|-----------------------------------|------------------------------------------------------|--------------------------------------------|
| Simple button / label             | `.glassEffect()`                                     | `.interactive()`                           |
| Group of controls                 | `GlassEffectContainer { ... }`                       | `.glassEffectID()`                         |
| Morphing selection                | `GlassEffectContainer` + `.glassEffectID()` + animation | `withAnimation(.spring(...))`              |
| Interactive control               | `.glassEffect(.regular.interactive())`               | `.interactive(true)`                       |
| Very subtle / minimal             | `.glassEffect(.clear)`                               | —                                          |
| Conditional modern look           | `@available` check or custom modifier                | Fallback to `.ultraThinMaterial`           |

This covers the primary usage patterns seen in Apple's official documentation, Landmarks sample code, and WWDC 2025 sessions. Let me know if you want deeper examples for specific use cases (e.g. navigation bars, sheets, custom transitions, accessibility integration).