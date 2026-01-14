# Dora Viewer Redesign - Development Plan

**Date:** 2026-01-13
**Author:** Claude (GLM-4.7)
**Project:** makepad-flow/examples/dora-viewer
**Version:** 1.0

---

## 1. Requirements Analysis

### 1.1 Overview
Transform the current single-panel dora-viewer into a three-panel split-screen application inspired by flex-layout-demo, with dataflow tree navigation, canvas visualization, and real-time system logging.

### 1.2 Functional Requirements

#### Panel 1: Left Panel - Dataflow Tree Navigator
| Requirement | Description | Priority |
|-------------|-------------|----------|
| **Tree hierarchy** | Display dataflow as unfoldable tree structure | P0 |
| **Node enable/disable** | Toggle individual nodes on/off via checkbox | P0 |
| **Port enable/disable** | Toggle individual ports (connectors) on/off | P0 |
| **Group enable/disable** | Batch enable/disable by node type or name pattern | P1 |
| **Search functionality** | Filter nodes by name in real-time | P1 |
| **Category filtering** | Filter nodes by category (MaaS, TTS, Bridge, etc.) | P1 |
| **Expand/collapse all** | Quick fold/unfold of entire tree | P2 |
| **Visual indicators** | Show enabled/disabled state with icons/colors | P0 |

#### Panel 2: Center Panel - Dataflow Visualization
| Requirement | Description | Priority |
|-------------|-------------|----------|
| **FlowCanvas display** | Render the dataflow graph | P0 |
| **Response to tree commands** | Update visualization based on left panel actions | P0 |
| **Disabled node visualization** | Show disabled nodes dimmed/grayed out | P0 |
| **Disabled edge visualization** | Hide or dim edges from disabled ports | P0 |
| **Single window** | No tabbing, one canvas view only | P0 |

#### Panel 3: Right Panel - System Log
| Requirement | Description | Priority |
|-------------|-------------|----------|
| **Real-time log display** | Show logs as they arrive | P0 |
| **Log filtering** | Filter by level (DEBUG, INFO, WARN, ERROR) | P1 |
| **Node filtering** | Filter logs by source node | P1 |
| **Search functionality** | Search log content | P1 |
| **Auto-scroll** | Scroll to latest logs | P1 |
| **Log limit** | Keep last N entries (prevent memory bloat) | P1 |
| **Copy to clipboard** | Export selected/all logs | P2 |

#### Layout & UX
| Requirement | Description | Priority |
|-------------|-------------|----------|
| **Resizable splitters** | Drag panel borders to resize | P0 |
| **Persist layout** | Save/restore panel sizes | P2 |
| **Min panel width** | Enforce minimum widths for usability | P0 |
| **Responsive** | Handle window resize gracefully | P0 |

---

## 2. Architecture Design

### 2.1 Reference Analysis

#### flex-layout-demo (`/Users/yuechen/home/dorobot/examples/flex-layout-demo`)
- Uses `Dock` widget with nested `Splitter` widgets
- Three-panel layout: LeftSidebar | ContentArea | RightSidebar
- Resizable splitters with `align: FromA(width)` and `align: FromB(width)`
- FileTree widget for hierarchical display

#### mofa-studio (`/Users/yuechen/home/mofa-studio`)
- `LogPanel` widget with `ScrollYView` + `Markdown` for rich log display
- Custom splitter drag handling with `FingerDown/Move/Up` events
- Filtering via `TextInput` (search) and `DropDown` (level/node filters)

### 2.2 Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Dora Viewer - Header/Toolbar                                    │
├──────────────┬──────────────────────────────────┬────────────────┤
│              │                                  │                │
│   Left       │       Center                     │    Right       │
│   Panel      │       Panel                      │    Panel       │
│              │                                  │                │
│ ┌──────────┐ │  ┌────────────────────────────┐ │ ┌────────────┐ │
│ │ [Search] │ │  │                            │ │ │ [Search]   │ │
│ ├──────────┤ │  │    FlowCanvas              │ │ ├────────────┤ │
│ │ ▼ Tree   │ │  │    (Dataflow Graph)        │ │ │ ▼ Level    │ │
│ │   ├─Node1│ │  │                            │ │ │   [All]    │ │
│ │   │  ☑text│ │  │    ┌──────┐              │ │ │ ▼ Node     │ │
│ │   │  ☑status│ │  │    │Node1 │────→Node2   │ │ │   [All]    │ │
│ │   └─Node2│ │  │    └──────┘              │ │ │             │ │
│ │   ...    │ │  │                            │ │ │ ┌─────────┐ │ │
│ │          │ │  │                            │ │ │ │ 12:34:56│ │ │
│ └──────────┘ │  └────────────────────────────┘ │ │ │ [INFO]  │ │ │
│              │                                  │ │ │ Node1:  │ │ │
│ ~~~~ Splitter ~~~~~~    ~~~~~ Splitter    ~~~~~ │ │ │ message │ │ │
│              │                                  │ │ └─────────┘ │ │
│              │                                  │ │      ...    │ │
├──────────────┴──────────────────────────────────┴────────────────┤
│ Status Bar: Nodes: 15 | Edges: 42 | Enabled: 12 | Disabled: 3   │
└───────────────────────────────────────────────────────────────────┘
```

### 2.3 Module Structure

```
examples/dora-viewer/
├── src/
│   ├── main.rs           # Entry point
│   ├── app.rs            # Main App struct (layout, event handling)
│   ├── dataflow_tree.rs  # Left panel tree widget + state
│   ├── dataflow_model.rs # Data model with enable/disable state
│   ├── log_panel.rs      # Right panel log widget
│   └── log_bridge.rs     # Optional: Dora log integration
├── dataflow/
│   └── voice-chat.yml    # Sample dataflow
└── Cargo.toml
```

### 2.4 Data Model Extension

#### New: `DataflowState` - Tree-aware model
```rust
// Extended from current FlowNode/EdgeConnection
pub struct DataflowState {
    pub nodes: Vec<NodeState>,
    pub edges: Vec<EdgeState>,
}

pub struct NodeState {
    pub base: FlowNode,
    pub enabled: bool,           // NEW: Master enable switch
    pub ports: HashMap<String, PortState>,  // NEW: Per-port state
}

pub struct PortState {
    pub enabled: bool,           // NEW: Individual port enable
    pub port: Port,              // Reference to base port
}

pub struct EdgeState {
    pub base: EdgeConnection,
    pub enabled: bool,           // NEW: Edge visibility
    pub source_port_enabled: bool,
    pub target_port_enabled: bool,
}
```

#### New: `LogEntry` - Structured log data
```rust
pub struct LogEntry {
    pub timestamp: String,
    pub level: LogLevel,
    pub source_node: String,
    pub message: String,
}

pub enum LogLevel {
    Debug,
    Info,
    Warning,
    Error,
}
```

---

## 3. Component Design

### 3.1 Left Panel: `DataflowTree`

#### Widget Structure
```rust
live_design! {
    DataflowTree = {{DataflowTree}} <View> {
        width: Fill, height: Fill
        flow: Down
        show_bg: true
        draw_bg: { color: #252538 }

        // Search bar
        search_row = <View> {
            width: Fill, height: Fit
            padding: 8
            flow: Down, spacing: 4

            search_input = <TextInput> {
                width: Fill, height: 28
                draw_bg: { color: #3d3d5c }
                text: "Search nodes..."
            }

            filter_row = <View> {
                width: Fill, height: Fit
                flow: Right, spacing: 4

                category_filter = <DropDown> {
                    width: Fill, height: 24
                    labels: ["All", "MaaS", "TTS", "Bridge", "Controller", "MoFA"]
                }

                expand_all = <Button> {
                    text: "Expand All"
                }
            }
        }

        // Tree view
        tree_scroll = <ScrollYView> {
            width: Fill, height: Fill
            show_scroll_y: true

            tree = <FileTree> {
                width: Fill, height: Fill
                node_height: 24
            }
        }

        // Footer with batch actions
        footer = <View> {
            width: Fill, height: Fit
            padding: 8

            <View> {
                flow: Right, spacing: 4
                enable_selected = <Button> { text: "Enable" }
                disable_selected = <Button> { text: "Disable" }
            }
        }
    }
}
```

#### Data Structure for Tree
```rust
#[derive(Live, LiveHook)]
pub struct DataflowTree {
    #[live] ui: WidgetRef,
    #[rust] state: DataflowState,
    #[rust] expanded_nodes: HashSet<String>,
    #[rust] search_filter: String,
    #[rust] category_filter: Option<NodeCategory>,
}

impl DataflowTree {
    // Build tree from dataflow state
    fn rebuild_tree(&mut self, cx: &mut Cx) {
        let mut tree_data = FileTreeData::new();

        for node_state in &self.state.nodes {
            // Apply filters
            if !self.matches_filter(node_state) {
                continue;
            }

            // Add node to tree
            let node_id = node_state.base.id.clone();
            let is_expanded = self.expanded_nodes.contains(&node_id);

            // Node item with checkbox
            tree_data.add_item(FileTreeItem {
                id: node_id.clone(),
                label: node_state.base.title.clone(),
                icon: Some(Self::category_icon(node_state.base.category)),
                is_expanded,
                has_children: !node_state.ports.is_empty(),
                // Checkbox for node enable/disable
                checked: Some(node_state.enabled),
                // Color code by category
                color: Some(node_state.base.category.color()),
            });

            // Add ports as children
            if is_expanded {
                for (port_id, port_state) in &node_state.ports {
                    let port_label = format!(
                        "{} {}",
                        if port_state.port.port_type == PortType::Input { "◀" } else { "▶" },
                        port_state.port.label
                    );
                    tree_data.add_item(FileTreeItem {
                        id: format!("{}/{}", node_id, port_id),
                        label: port_label,
                        is_expanded: false,
                        has_children: false,
                        checked: Some(port_state.enabled),
                        indent: 1,
                        ..Default::default()
                    });
                }
            }
        }

        self.ui.file_tree(id!(tree)).set_data(cx, tree_data);
    }

    fn matches_filter(&self, node: &NodeState) -> bool {
        // Search filter
        if !self.search_filter.is_empty() {
            let search_lower = self.search_filter.to_lowercase();
            if !node.base.title.to_lowercase().contains(&search_lower)
                && !node.base.id.to_lowercase().contains(&search_lower) {
                return false;
            }
        }

        // Category filter
        if let Some(cat) = self.category_filter {
            if node.base.category != cat {
                return false;
            }
        }

        true
    }
}
```

### 3.2 Center Panel: Enhanced FlowCanvas

#### Required Changes to FlowCanvas
```rust
// Add to FlowCanvas
impl FlowCanvas {
    // NEW: Set node enable state
    pub fn set_node_enabled(&mut self, cx: &mut Cx, node_id: &str, enabled: bool) {
        if let Some(node) = self.nodes.iter_mut().find(|n| n.id == node_id) {
            // Store enabled state (need to add field)
            // Trigger redraw with dimmed appearance
        }
    }

    // NEW: Set port enable state
    pub fn set_port_enabled(&mut self, cx: &mut Cx, node_id: &str, port_id: &str, enabled: bool) {
        // Update port state
        // Recalculate affected edges
        self.update_edges_for_port(cx, node_id, port_id, enabled);
    }

    // NEW: Update edge visibility based on port states
    fn update_edges_for_port(&mut self, cx: &mut Cx, node_id: &str, port_id: &str, enabled: bool) {
        for edge in &mut self.edges {
            if edge.from_node == node_id && edge.from_port == port_id {
                edge.enabled = enabled && self.is_port_enabled(edge.to_node, &edge.to_port);
            }
            // Similar for target port
        }
    }

    // NEW: Render disabled nodes dimmed
    fn draw_node(&self, cx: &mut Cx, node: &FlowNode) {
        let is_enabled = self.node_enabled.get(&node.id).unwrap_or(&true);
        let alpha = if *is_enabled { 1.0 } else { 0.3 };

        // Draw node with modified alpha
        // ...
    }
}
```

#### Visual States
| State | Appearance |
|-------|------------|
| Node enabled | Full opacity, normal colors |
| Node disabled | 30% opacity, grayed out |
| Port enabled | Full color, visible |
| Port disabled | Grayed out, edges hidden |
| Edge enabled | Full bezier curve |
| Edge disabled | Hidden or dashed gray line |

### 3.3 Right Panel: `LogPanel`

#### Widget Structure
```rust
live_design! {
    LogPanel = {{LogPanel}} <View> {
        width: Fill, height: Fill
        flow: Down
        show_bg: true
        draw_bg: { color: #1a1a2e }

        // Header with filters
        header = <View> {
            width: Fill, height: Fit
            padding: 8
            flow: Down, spacing: 4

            title_row = <View> {
                width: Fill, height: Fit
                flow: Right

                title_label = <Label> {
                    draw_text: { color: #e0e0e0, font_size: 12.0 }
                    text: "System Log"
                }
                <View> { width: Fill, height: 1 }
                clear_btn = <Button> {
                    text: "Clear"
                    draw_bg: { color: #3d3d5c }
                }
            }

            filter_row = <View> {
                width: Fill, height: Fit
                flow: Right, spacing: 4

                search_input = <TextInput> {
                    width: Fill, height: 24
                    draw_bg: { color: #3d3d5c }
                    text: "Search logs..."
                }

                level_filter = <DropDown> {
                    width: 80, height: 24
                    labels: ["All", "DEBUG", "INFO", "WARN", "ERROR"]
                    values: [all, debug, info, warn, error]
                }
            }
        }

        // Log content with scroll
        log_scroll = <ScrollYView> {
            width: Fill, height: Fill
            scroll_bar_width: 8.0

            log_content = <Markdown> {
                width: Fill, height: Fit
                draw_text: {
                    text_style: { font_size: 10.0, font_family: "Courier" }
                    color: #a0a0b0
                }
                paragraph_spacing: 2
                line_spacing: 1.2
            }
        }

        // Footer with status
        footer = <View> {
            width: Fill, height: 20
            padding: { left: 8, right: 8 }
            align: { y: 0.5 }

            status_label = <Label> {
                draw_text: { color: #606080, font_size: 9.0 }
                text: "0 entries"
            }
        }
    }
}
```

#### Log Management
```rust
#[derive(Live, LiveHook)]
pub struct LogPanel {
    #[live] ui: WidgetRef,
    #[rust] entries: Vec<LogEntry>,
    #[rust] max_entries: usize,
    #[rust] level_filter: LogLevelFilter,
    #[rust] search_filter: String,
    #[rust] auto_scroll: bool,
}

impl LogPanel {
    pub const MAX_ENTRIES: usize = 1000;

    pub fn add_log(&mut self, cx: &mut Cx, entry: LogEntry) {
        // Add to entries
        self.entries.push(entry);

        // Prune old entries
        if self.entries.len() > Self::MAX_ENTRIES {
            let excess = self.entries.len() - Self::MAX_ENTRIES;
            self.entries.drain(0..excess);
        }

        // Update display
        self.refresh_display(cx);
    }

    fn refresh_display(&mut self, cx: &mut Cx) {
        let filtered: Vec<_> = self.entries.iter()
            .filter(|e| self.matches_level_filter(e))
            .filter(|e| self.matches_search_filter(e))
            .map(|e| self.format_log_entry(e))
            .collect();

        let log_text = filtered.join("\n\n");
        self.ui.markdown(id!(log_content)).set_text(cx, &log_text);

        // Update status
        let status = format!("{} / {} entries", filtered.len(), self.entries.len());
        self.ui.label(id!(status_label)).set_text(cx, &status);

        // Auto-scroll if enabled
        if self.auto_scroll {
            self.ui.scroll_y_view(id!(log_scroll)).scroll_to_end(cx);
        }
    }

    fn format_log_entry(&self, entry: &LogEntry) -> String {
        let level_color = match entry.level {
            LogLevel::Debug => "#8080a0",
            LogLevel::Info => "#4a90d9",
            LogLevel::Warning => "#f59e0b",
            LogLevel::Error => "#ef4444",
        };

        format!(
            "**{}** [{}](fg:{}) `{}`: {}",
            entry.timestamp,
            format!("{:?}", entry.level).to_uppercase(),
            level_color,
            entry.source_node,
            entry.message
        )
    }
}
```

### 3.4 Main Layout: Three-Panel with Splitters

#### Layout Structure
```rust
live_design! {
    App = {{App}} {
        ui: <Window> {
            window: { title: "Dora Viewer", inner_size: vec2(1600, 1000) }
            show_bg: true
            draw_bg: { color: #1a1a2e }

            body = <View> {
                width: Fill, height: Fill
                flow: Down

                // Top toolbar
                toolbar = <View> {
                    width: Fill, height: 40
                    padding: { left: 12, right: 12 }
                    spacing: 8
                    align: { y: 0.5 }
                    show_bg: true
                    draw_bg: { color: #252538 }

                    <Label> {
                        draw_text: { color: #e0e0e0, font_size: 14.0 }
                        text: "Dora Viewer"
                    }

                    <View> { width: Fill, height: 1 }

                    file_label = <Label> {
                        draw_text: { color: #8080a0, font_size: 10.0 }
                        text: "No file loaded"
                    }

                    reload_btn = <Button> {
                        text: "Reload"
                        draw_bg: { color: #3d3d5c }
                    }
                }

                // Main area with three panels
                main_area = <View> {
                    width: Fill
                    height: Fill
                    flow: Right
                    spacing: 0

                    // Left panel - Dataflow tree
                    left_panel = <View> {
                        width: 300
                        height: Fill
                        flow: Down

                        dataflow_tree = <DataflowTree> {}
                    }

                    // Left splitter
                    left_splitter = <View> {
                        width: 4
                        height: Fill
                        cursor: ColResize
                        show_bg: true
                        draw_bg: { color: #3d3d5c }
                    }

                    // Center panel - FlowCanvas
                    center_panel = <View> {
                        width: Fill
                        height: Fill
                        flow: Down

                        canvas = <FlowCanvas> {}
                    }

                    // Right splitter
                    right_splitter = <View> {
                        width: 4
                        height: Fill
                        cursor: ColResize
                        show_bg: true
                        draw_bg: { color: #3d3d5c }
                    }

                    // Right panel - Log panel
                    right_panel = <View> {
                        width: 400
                        height: Fill
                        flow: Down

                        log_panel = <LogPanel> {}
                    }
                }

                // Bottom status bar
                status_bar = <View> {
                    width: Fill
                    height: 24
                    padding: { left: 12, right: 12 }
                    align: { y: 0.5 }
                    show_bg: true
                    draw_bg: { color: #252538 }

                    count_label = <Label> {
                        draw_text: { color: #8080a0, font_size: 9.0 }
                        text: "Nodes: 0 | Edges: 0 | Enabled: 0 | Disabled: 0"
                    }
                }
            }
        }
    }
}
```

#### Splitter Handling
```rust
impl App {
    #[rust]
    left_dragging: bool,
    #[rust]
    right_dragging: bool,
    #[rust]
    left_panel_width: f64,
    #[rust]
    right_panel_width: f64,

    const MIN_LEFT_WIDTH: f64 = 200.0;
    const MIN_RIGHT_WIDTH: f64 = 250.0;
    const MIN_CENTER_WIDTH: f64 = 400.0;

    fn handle_splitter_events(&mut self, cx: &mut Cx, event: &Event) {
        // Left splitter
        let left_splitter_area = self.ui.view(id!(left_splitter)).area();
        match event.hits(cx, left_splitter_area) {
            Hit::FingerDown(_) => {
                self.left_dragging = true;
            }
            Hit::FingerMove(fm) => {
                if self.left_dragging {
                    let new_width = (fm.abs.x - self.ui.area().rect(cx).pos.x)
                        .max(Self::MIN_LEFT_WIDTH);

                    self.left_panel_width = new_width;
                    self.ui.view(id!(left_panel)).apply_over(cx, live!{
                        width: (new_width)
                    });
                    self.ui.redraw(cx);
                }
            }
            Hit::FingerUp(_) => {
                self.left_dragging = false;
            }
            _ => {}
        }

        // Similar for right splitter...
    }
}
```

---

## 4. Implementation Phases

### Phase 1: Foundation (Week 1)
**Goal:** Basic three-panel layout with splitters

| Task | File | Description |
|------|------|-------------|
| 1.1 | `app.rs` | Redesign layout with three panels |
| 1.2 | `app.rs` | Implement splitter drag handling |
| 1.3 | `app.rs` | Add minimum width constraints |
| 1.4 | `dataflow_model.rs` | Create DataflowState struct |
| 1.5 | `dataflow_model.rs` | Add NodeState and PortState |
| 1.6 | `dataflow_model.rs` | Implement enable/disable logic |

**Deliverable:** Three-panel layout with resizable splitters, no functional panels yet.

### Phase 2: Left Panel - Dataflow Tree (Week 2)
**Goal:** Functional tree with node/port enable/disable

| Task | File | Description |
|------|------|-------------|
| 2.1 | `dataflow_tree.rs` | Create DataflowTree widget |
| 2.2 | `dataflow_tree.rs` | Implement tree building from YAML |
| 2.3 | `dataflow_tree.rs` | Add expand/collapse functionality |
| 2.4 | `dataflow_tree.rs` | Add checkboxes for nodes/ports |
| 2.5 | `dataflow_tree.rs` | Emit events on checkbox toggle |
| 2.6 | `dataflow_tree.rs` | Implement search filtering |
| 2.7 | `dataflow_tree.rs` | Implement category filtering |
| 2.8 | `app.rs` | Wire tree events to data model |

**Deliverable:** Functional tree panel with enable/disable toggles.

### Phase 3: Center Panel Integration (Week 2-3)
**Goal:** Canvas responds to tree state changes

| Task | File | Description |
|------|------|-------------|
| 3.1 | `flow_canvas.rs` | Add enabled state to FlowNode |
| 3.2 | `flow_canvas.rs` | Add enabled state to Port |
| 3.3 | `flow_canvas.rs` | Add enabled state to EdgeConnection |
| 3.4 | `flow_canvas.rs` | Implement dimmed rendering for disabled |
| 3.5 | `flow_canvas.rs` | Hide edges from disabled ports |
| 3.6 | `flow_canvas.rs` | Add FlowCanvasCommand::SetNodeEnabled |
| 3.7 | `flow_canvas.rs` | Add FlowCanvasCommand::SetPortEnabled |
| 3.8 | `app.rs` | Wire tree events to canvas commands |
| 3.9 | `app.rs` | Synchronize state between tree and canvas |

**Deliverable:** Canvas updates visually when tree checkboxes are toggled.

### Phase 4: Right Panel - System Log (Week 3-4)
**Goal:** Real-time log display with filtering

| Task | File | Description |
|------|------|-------------|
| 4.1 | `log_panel.rs` | Create LogPanel widget |
| 4.2 | `log_panel.rs` | Implement Markdown rendering |
| 4.3 | `log_panel.rs` | Add log level filtering |
| 4.4 | `log_panel.rs` | Add node/source filtering |
| 4.5 | `log_panel.rs` | Add search functionality |
| 4.6 | `log_panel.rs` | Implement entry limit/pruning |
| 4.7 | `log_panel.rs` | Add auto-scroll |
| 4.8 | `app.rs` | Create mock log generator (for testing) |
| 4.9 | `log_bridge.rs` | (Optional) Integrate with Dora log system |

**Deliverable:** Functional log panel with real-time updates.

### Phase 5: Integration & Polish (Week 4)
**Goal:** Complete application with UX refinements

| Task | File | Description |
|------|------|-------------|
| 5.1 | `app.rs` | Update status bar with counts |
| 5.2 | `app.rs` | Add file reload functionality |
| 5.3 | `dataflow_tree.rs` | Add "Enable All/Disable All" |
| 5.4 | `dataflow_tree.rs` | Add batch enable by type |
| 5.5 | `flow_canvas.rs` | Add keyboard shortcuts |
| 5.6 | All | Refine styling and colors |
| 5.7 | All | Add tooltips |
| 5.8 | All | Performance optimization |
| 5.9 | All | Testing and bug fixes |

**Deliverable:** Production-ready dora-viewer application.

---

## 5. Event Flow Diagrams

### 5.1 Node Enable/Disable Flow

```
User clicks checkbox in tree
        ↓
DataflowTree::handle_click
        ↓
Emit TreeAction::NodeToggled { node_id, enabled }
        ↓
App::handle_tree_actions
        ↓
Update DataflowState.nodes[node_id].enabled
        ↓
Send FlowCanvasCommand::SetNodeEnabled { node_id, enabled }
        ↓
FlowCanvas::set_node_enabled
        ↓
Recalculate affected edges
        ↓
Trigger redraw with dimmed appearance
        ↓
User sees updated visualization
```

### 5.2 Log Flow

```
Log source (Dora/Mock)
        ↓
LogEntry created
        ↓
LogPanel::add_log(entry)
        ↓
Prune old entries (> MAX)
        ↓
Apply filters (level, search, node)
        ↓
Build Markdown display string
        ↓
Update Markdown widget
        ↓
Auto-scroll to bottom
        ↓
User sees new log entry
```

### 5.3 Splitter Resize Flow

```
User drags splitter handle
        ↓
Hit::FingerDown on splitter area
        ↓
Set dragging = true
        ↓
Hit::FingerMove with new position
        ↓
Calculate new panel width
        ↓
Enforce min/max constraints
        ↓
Apply width to panel via apply_over
        ↓
Trigger redraw
        ↓
Hit::FingerUp
        ↓
Set dragging = false
```

---

## 6. Testing Strategy

### 6.1 Unit Tests
```rust
#[cfg(test)]
mod tests {
    // Data model tests
    #[test]
    fn test_node_state_toggle() {
        let mut node = NodeState::new(...);
        assert!(node.enabled);
        node.set_enabled(false);
        assert!(!node.enabled);
    }

    #[test]
    fn test_port_disables_edge() {
        // Test that disabling a port disables connected edges
    }

    #[test]
    fn test_filter_search() {
        // Test search filtering logic
    }

    // Tree tests
    #[test]
    fn test_tree_building() {
        // Test tree data structure building
    }

    // Log tests
    #[test]
    fn test_log_pruning() {
        // Test max entries limit
    }
}
```

### 6.2 Integration Tests
- Load voice-chat.yml and verify all nodes appear in tree
- Toggle node and verify canvas updates
- Disable port and verify edges are hidden
- Add logs and verify display and filtering
- Resize panels and verify constraints

### 6.3 Manual Testing Checklist
- [ ] Panel resize works smoothly
- [ ] Search filters correctly
- [ ] Category filters work
- [ ] Node enable/disable affects all ports
- [ ] Port enable/disable affects connected edges
- [ ] Log filtering by level works
- [ ] Log search works
- [ ] Auto-scroll functions
- [ ] Keyboard shortcuts work
- [ ] Layout persists across window resize

---

## 7. Dependencies

### 7.1 New Dependencies (if any)
```toml
[dependencies]
makepad-widgets = { git = "https://github.com/makepad/makepad", branch = "rik" }
makepad-flow = { path = "../../crates/makepad-flow" }
serde = { version = "1.0", features = ["derive"] }
serde_yaml = "0.9"

# For log parsing (if integrating with Dora)
chrono = "0.4"  # For timestamps
```

### 7.2 FileTree Widget Availability
**Note:** Need to verify `FileTree` widget availability in the Makepad version being used. If not available:
- Use alternative: Custom tree with `<View>` hierarchy
- Or implement simple tree with expand/collapse

### 7.3 Markdown Widget Availability
**Note:** Need to verify `<Markdown>` widget availability. If not available:
- Use `<Label>` with plain text
- Or implement custom rich text display

---

## 8. Risk Assessment & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| FileTree widget unavailable | High | Medium | Implement custom tree or use collapsible View hierarchy |
| Multi-port rendering performance | Medium | Low | Implement culling for large graphs |
| Log memory growth | Medium | Medium | Implement strict entry limit with pruning |
| Splitter drag UX issues | Low | Medium | Test thoroughly, add visual feedback |
| State sync complexity | High | High | Use single source of truth (DataflowState) |
| Makepad API changes | High | Low | Pin dependency version, abstract widget usage |

---

## 9. Success Criteria

### 9.1 Functional Requirements
- [x] Three-panel layout with resizable splitters
- [ ] Tree shows all nodes from voice-chat.yml
- [ ] Checkbox enables/disables individual nodes
- [ ] Checkbox enables/disables individual ports
- [ ] Canvas reflects enable state visually
- [ ] Edges from disabled ports are hidden
- [ ] Logs display in real-time
- [ ] Logs filter by level and content
- [ ] Search works for both tree and logs

### 9.2 Performance Requirements
- [ ] Panel resize < 16ms (60fps)
- [ ] Tree rebuild < 100ms for 50 nodes
- [ ] Canvas update < 16ms on state change
- [ ] Log panel handles 1000+ entries smoothly
- [ ] Memory use < 100MB with 50 nodes

### 9.3 UX Requirements
- [ ] Minimum panel widths enforced
- [ ] Keyboard shortcuts documented
- [ ] Visual feedback for all actions
- [ ] Consistent color scheme
- [ ] Accessible text sizes and contrast

---

## 10. Future Enhancements (Post-MVP)

| Feature | Description | Priority |
|---------|-------------|----------|
| Layout persistence | Save/restore panel sizes | P2 |
| MiniMap | Add to center panel | P1 |
| Node properties panel | Show in right panel tab | P1 |
| Export configuration | Save enable/disable state | P2 |
| Undo/redo | For enable/disable actions | P2 |
| Real Dora integration | Connect to running dataflow | P0 (later) |
| Log panel tabs | Switch between logs and properties | P2 |
| Visual diff | Show changes before/after toggle | P3 |
| Drag-drop tree reorder | Reorganize nodes | P3 |

---

## Appendix A: Quick Reference - Key File Paths

| Reference | Path |
|-----------|------|
| flex-layout-demo | `/Users/yuechen/home/dorobot/examples/flex-layout-demo/src/app.rs` |
| mofa-fm log panel | `/Users/yuechen/home/mofa-studio/apps/mofa-fm/src/screen/log_panel.rs` |
| mofa log widget | `/Users/yuechen/home/mofa-studio/mofa-widgets/src/log_panel.rs` |
| Current dora-viewer | `/Users/yuechen/home/dora-studio/makepad-flow/examples/dora-viewer/src/app.rs` |
| FlowCanvas widget | `/Users/yuechen/home/dora-studio/makepad-flow/crates/makepad-flow/src/flow_canvas.rs` |
| Sample dataflow | `/Users/yuechen/home/dora-studio/makepad-flow/examples/dora-viewer/dataflow/voice-chat.yml` |

---

## Appendix B: Code Snippets - Key Patterns

### B.1 FileTree Usage (from flex-layout-demo)
```rust
// Set tree data
let mut tree_data = FileTreeData::new();
tree_data.add_root(FileTreeItem {
    id: "root".to_string(),
    label: "Dataflow".to_string(),
    ..Default::default()
});
self.ui.file_tree(id!(tree)).set_data(cx, tree_data);

// Handle selection
if let Some(item_id) = self.ui.file_tree(id!(tree)).selected(actions) {
    log!("Selected: {}", item_id);
}
```

### B.2 Splitter Handling (from mofa-fm)
```rust
match event.hits(cx, splitter_area) {
    Hit::FingerDown(_) => {
        self.dragging = true;
    }
    Hit::FingerMove(fm) => {
        if self.dragging {
            let new_width = calculate_width(fm.abs.x);
            self.panel.apply_over(cx, live!{ width: (new_width) });
            self.redraw(cx);
        }
    }
    Hit::FingerUp(_) => {
        self.dragging = false;
    }
    _ => {}
}
```

### B.3 Log Panel Pattern (from mofa-studio)
```rust
pub fn add_log(&mut self, cx: &mut Cx, text: &str) {
    self.entries.push(text.to_string());
    self.prune_entries();
    self.update_display(cx);
}

fn update_display(&mut self, cx: &mut Cx) {
    let filtered = self.entries.iter()
        .filter(|e| self.matches_filter(e))
        .collect::<Vec<_>>()
        .join("\n\n");
    self.ui.markdown(id!(content)).set_text(cx, &filtered);
}
```

---

**End of Development Plan**
