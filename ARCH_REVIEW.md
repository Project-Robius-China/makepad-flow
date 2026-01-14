# Architecture Review: makepad-flow

## Overview

makepad-flow is a flow/node editor widget library for Makepad. This review analyzes its architecture and identifies areas for improvement to make it a better reusable Makepad widget.

## Current Structure

```
crates/makepad-flow/
├── Cargo.toml
└── src/
    ├── lib.rs           # Re-exports, live_design registration
    └── flow_canvas.rs   # Everything else (2434 lines)
```

## Issues

### 1. Monolithic File Structure

**Problem**: All code lives in a single 2434-line file containing:
- 3 custom shader structs (DrawRoundedRect, DrawRoundedTopRect, DrawRoundedBottomRect)
- 6 enums (NodeShape, NodeCategory, NodeType, EdgeMarker, DragState, etc.)
- 4 data structs (FlowNode, EdgeConnection, Port, HistoryEntry)
- 2 command/action enums
- 1 large widget implementation

**Recommendation**: Split into focused modules:
```
src/
├── lib.rs              # Public API, re-exports
├── shaders.rs          # DrawRoundedRect, DrawRoundedTopRect, DrawRoundedBottomRect
├── node.rs             # FlowNode, NodeShape, NodeType, Port
├── edge.rs             # EdgeConnection, EdgeMarker
├── canvas.rs           # FlowCanvas widget implementation
├── actions.rs          # FlowCanvasCommand, FlowCanvasAction
└── history.rs          # HistoryEntry, undo/redo logic
```

### 2. Hardcoded Imperative Drawing

**Problem**: Node and edge rendering is entirely imperative in `draw_walk()`:
```rust
fn draw_walk(&mut self, cx: &mut Cx2d, ...) -> DrawStep {
    // 300+ lines of manual drawing code
    self.draw_rounded_rect.draw_abs(cx, rect);
    self.draw_text.draw_abs(cx, pos, &label);
    // ...
}
```

The `live_design!` macro defines node templates (NodeCamera, NodeProcessor) that are never used.

**Recommendation**:
- Use Makepad's widget composition for nodes
- Create a `FlowNode` widget that can be styled via DSL
- Use `PortalList` or similar for efficient node rendering

### 3. No Live Property Support

**Problem**: Visual properties use `#[rust]` instead of `#[live]`:
```rust
pub struct FlowCanvas {
    #[rust] line_width: f32,      // Not configurable via DSL
    #[rust] line_style: f32,      // Not configurable via DSL
    #[rust] zoom: f64,            // Not configurable via DSL
}
```

**Impact**: Users cannot customize the widget declaratively:
```rust
// This doesn't work:
<FlowCanvas> {
    line_width: 2.0
    default_node_color: #4a90d9
    grid_visible: true
}
```

**Recommendation**: Convert visual properties to `#[live]`:
```rust
pub struct FlowCanvas {
    #[live] line_width: f32,
    #[live] line_style: f32,
    #[live] default_zoom: f64,
    #[live] background_color: Vec4,
    #[live] grid_color: Vec4,
    #[live] selection_color: Vec4,
}
```

### 4. Domain-Specific Code in Library

**Problem**: `NodeCategory` contains Dora-specific values:
```rust
pub enum NodeCategory {
    Default,
    MaaS,       // LLM clients (blue)
    TTS,        // Text-to-speech (green)
    Bridge,     // Message routing (orange)
    Controller, // Orchestration (purple)
    MoFA,       // Dynamic UI widgets (cyan)
    Segmenter,  // Text processing (yellow)
}
```

**Recommendation**:
- Remove domain-specific categories from library
- Use generic approach: `node.color: Vec4` or callback-based coloring
- Move Dora-specific categorization to dora-viewer

### 5. Command Pattern via Global Actions

**Problem**: Commands are dispatched through global action system:
```rust
// In parent app:
cx.action(FlowCanvasCommand::AddNode);
cx.action(FlowCanvasCommand::LoadDataflow { nodes, edges });
```

This requires the parent to understand internal command structure.

**Recommendation**: Provide direct methods via WidgetRef:
```rust
// Better API:
let canvas = self.ui.flow_canvas(id!(canvas));
canvas.add_node(node);
canvas.load_dataflow(nodes, edges);
canvas.fit_view();
```

### 6. Missing FlowCanvasRef

**Problem**: No type-safe widget reference implementation:
```rust
// Current: No way to get typed reference
let canvas = self.ui.widget(id!(canvas));  // Returns generic WidgetRef

// Should have:
let canvas = self.ui.flow_canvas(id!(canvas));  // Returns FlowCanvasRef
```

**Recommendation**: Implement `FlowCanvasRef` with builder methods:
```rust
#[derive(Clone, WidgetRef)]
pub struct FlowCanvasRef(WidgetRef);

impl FlowCanvasRef {
    pub fn add_node(&self, cx: &mut Cx, node: FlowNode) { ... }
    pub fn remove_node(&self, cx: &mut Cx, id: &str) { ... }
    pub fn add_edge(&self, cx: &mut Cx, edge: EdgeConnection) { ... }
    pub fn load_dataflow(&self, cx: &mut Cx, nodes: Vec<FlowNode>, edges: Vec<EdgeConnection>) { ... }
    pub fn fit_view(&self, cx: &mut Cx) { ... }
    pub fn get_selected_nodes(&self) -> Vec<usize> { ... }
}
```

### 7. Initialization in handle_event

**Problem**: Widget initialization happens in event handler:
```rust
fn handle_event(&mut self, cx: &mut Cx, event: &Event, scope: &mut Scope) {
    if !self.initialized {
        self.initialize(cx);  // Side effect in event handler
    }
    // ...
}
```

**Recommendation**: Use Makepad's lifecycle hooks:
```rust
impl LiveHook for FlowCanvas {
    fn after_apply(&mut self, cx: &mut Cx, ...) {
        self.initialize(cx);
    }
}
```

### 8. No Event Callbacks

**Problem**: Parent must poll actions to react to changes:
```rust
// Current approach in parent:
for action in actions {
    if let FlowCanvasAction::NodeAdded = action.cast() {
        // handle
    }
}
```

**Recommendation**: Support callback closures or widget actions:
```rust
<FlowCanvas> {
    on_node_added: { /* handler */ }
    on_edge_created: { /* handler */ }
    on_selection_changed: { /* handler */ }
}
```

## What's Done Well

### Proper Makepad Patterns
- Correct use of `#[derive(Live, LiveHook, Widget)]`
- Clean `live_design!` macro usage for shaders
- Proper action/command separation

### Custom Shaders
- Well-implemented SDF shaders for rounded rectangles
- Proper `DrawQuad` extension pattern
- Clean shader composition with `fill_keep()`

### Feature Completeness
- Multi-selection support
- Undo/redo stack
- Keyboard shortcuts
- Context menus
- Edge animations
- Multiple node shapes

## Recommended Refactoring Priority

1. **High**: Add `FlowCanvasRef` with direct methods
2. **High**: Make visual properties `#[live]` configurable
3. **Medium**: Split into multiple modules
4. **Medium**: Remove domain-specific `NodeCategory`
5. **Low**: Use widget composition for nodes
6. **Low**: Add event callbacks

## Example: Ideal API

```rust
live_design! {
    <FlowCanvas> {
        width: Fill, height: Fill

        // Configurable via DSL
        line_width: 2.0
        line_style: solid
        background_color: #1e1e32
        grid_visible: true
        grid_color: #2a2a4a

        // Default node appearance
        default_node_width: 180.0
        default_node_color: #2d2d44
        default_header_color: #3d3d5c
    }
}

// In Rust code:
impl MatchEvent for App {
    fn handle_actions(&mut self, cx: &mut Cx, actions: &Actions) {
        let canvas = self.ui.flow_canvas(id!(canvas));

        if self.ui.button(id!(add_btn)).clicked(actions) {
            canvas.add_node(cx, FlowNode::new("node1", 100.0, 100.0));
        }

        // React to canvas events
        if let Some(node_id) = canvas.node_selected(actions) {
            log!("Selected: {}", node_id);
        }
    }
}
```

## Conclusion

makepad-flow has solid foundations but needs refactoring to be a proper reusable Makepad widget. The main issues are:
1. Lack of DSL configurability
2. Missing type-safe widget reference
3. Domain-specific code mixed with library code
4. Monolithic file structure

Addressing these would make it a first-class Makepad widget suitable for general use.
