# Dora Viewer Enhancement Plan

## Requirements Analysis

### 1. Left Panel - Dataflow Tree
- Display dataflow YAML as hierarchical tree (like FileTree widget)
- Unfoldable structure: Nodes → Inputs/Outputs → Connections
- Enable/disable individual nodes (checkbox)
- Enable/disable individual connectors (input/output ports)
- Search nodes by name
- Bulk enable/disable connectors by name pattern or type

### 2. Center Panel - Flow Visualization
- Single FlowCanvas window showing dataflow graph
- Responds to enable/disable commands from tree
- Disabled nodes/edges shown grayed out or with visual indicator
- Updates in real-time when tree selection changes

### 3. Right Panel - System Log
- Real-time log display (like mofa-studio)
- Filter by log level (DEBUG, INFO, WARN, ERROR)
- Filter by node source
- Search text
- Auto-scroll with pause capability

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Header: "Dora Viewer" + YAML file selector                    │
├──────────────┬───────────────────────────┬─────────────────────┤
│ Left Panel   │   Center Panel            │  Right Panel        │
│ (280px)      │   (Fill)                  │  (320px)            │
│              │                           │                     │
│ DataflowTree │   FlowCanvas              │  LogPanel           │
│ ┌──────────┐ │   ┌───────────────────┐   │  ┌───────────────┐  │
│ │ Search   │ │   │                   │   │  │ Level Filter  │  │
│ ├──────────┤ │   │   Node Graph      │   │  │ Node Filter   │  │
│ │ ☑ node1  │ │   │                   │   │  │ Search        │  │
│ │  ├ inputs│ │   │   [A]──────[B]    │   │  ├───────────────┤  │
│ │  │ ☑ in1 │ │   │                   │   │  │ [INFO] msg    │  │
│ │  └outputs│ │   │   [C]──────[D]    │   │  │ [WARN] msg    │  │
│ │ ☑ node2  │ │   │                   │   │  │ [ERROR] msg   │  │
│ │ ☐ node3  │ │   └───────────────────┘   │  └───────────────┘  │
│ └──────────┘ │                           │                     │
├──────────────┴───────────────────────────┴─────────────────────┤
│  Status Bar: Nodes: 14 | Edges: 71 | Enabled: 10/14           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Model

### DataflowState (Shared State)
```rust
pub struct DataflowState {
    // Node visibility
    pub node_enabled: HashMap<String, bool>,
    pub connector_enabled: HashMap<String, bool>,  // "node_id/port_name"

    // Log entries
    pub logs: Vec<LogEntry>,

    // Selection state
    pub selected_node: Option<String>,
    pub search_query: String,
}

pub struct LogEntry {
    pub level: LogLevel,
    pub node_id: String,
    pub message: String,
    pub timestamp: u64,
}

pub enum LogLevel {
    Debug,
    Info,
    Warn,
    Error,
}
```

### DataflowTreeNode (Tree Structure)
```rust
pub enum DataflowTreeNode {
    Root { children: Vec<DataflowTreeNode> },
    Node {
        id: String,
        enabled: bool,
        inputs: Vec<PortTreeNode>,
        outputs: Vec<PortTreeNode>,
    },
    Category {
        name: String,  // "MaaS", "TTS", "Bridge", etc.
        children: Vec<DataflowTreeNode>,
    },
}

pub struct PortTreeNode {
    pub name: String,
    pub enabled: bool,
    pub connections: Vec<String>,  // Connected node/port names
}
```

---

## Implementation Phases

### Phase 1: Layout Foundation (2-3 days)

#### 1.1 Create Split Panel Layout
- Copy Splitter/Dock pattern from flex-layout-demo
- Three-panel horizontal layout with resizable dividers
- Left: 280px default, min 200px
- Right: 320px default, min 200px
- Center: Fill remaining space

**Files to create:**
- `src/layout.rs` - Splitter and panel container widgets
- Update `src/app.rs` - New live_design with 3-panel layout

**Key widgets needed:**
```rust
live_design! {
    DoraViewerLayout = <View> {
        width: Fill, height: Fill
        flow: Right

        left_panel = <View> {
            width: 280, height: Fill
            // DataflowTree goes here
        }

        <Splitter> { axis: Horizontal }

        center_panel = <View> {
            width: Fill, height: Fill
            // FlowCanvas goes here
        }

        <Splitter> { axis: Horizontal }

        right_panel = <View> {
            width: 320, height: Fill
            // LogPanel goes here
        }
    }
}
```

#### 1.2 Panel Collapse/Expand
- Toggle buttons to collapse left/right panels
- Smooth animation on collapse
- Remember panel sizes

---

### Phase 2: Dataflow Tree Widget (3-4 days)

#### 2.1 Create DataflowTree Widget
- Based on Makepad FileTree pattern
- Custom tree node rendering with checkboxes

**Widget structure:**
```rust
#[derive(Live, LiveHook, Widget)]
pub struct DataflowTree {
    #[deref] view: View,
    #[rust] tree_data: Vec<DataflowTreeNode>,
    #[rust] expanded_nodes: HashSet<String>,
    #[rust] node_enabled: HashMap<String, bool>,
    #[rust] search_filter: String,
}
```

**Live design:**
```rust
DataflowTree = {{DataflowTree}} {
    width: Fill, height: Fill
    flow: Down

    // Search bar
    search_bar = <View> {
        width: Fill, height: 36
        padding: 8
        search_input = <TextInput> {
            empty_text: "Search nodes..."
        }
    }

    // Tree scroll area
    tree_scroll = <ScrollYView> {
        width: Fill, height: Fill
        tree_content = <View> {
            width: Fill, height: Fit
            flow: Down
        }
    }

    // Bulk actions toolbar
    actions_bar = <View> {
        width: Fill, height: 40
        enable_all_btn = <Button> { text: "Enable All" }
        disable_all_btn = <Button> { text: "Disable All" }
    }
}
```

#### 2.2 Tree Node Types

**Category Node (collapsible header):**
```
▼ MaaS Nodes (3)
  ☑ student1
  ☑ student2
  ☑ tutor
```

**Node Entry (with checkbox + expand):**
```
  ▼ ☑ student1
      Inputs:
        ☑ text (← bridge-to-student1/text)
        ☑ control (← controller/llm_control)
      Outputs:
        ☑ text
        ☑ status
        ☑ log
```

#### 2.3 Tree Actions
```rust
#[derive(Clone, Debug, DefaultNone)]
pub enum DataflowTreeAction {
    None,
    NodeToggled { node_id: String, enabled: bool },
    ConnectorToggled { node_id: String, port: String, enabled: bool },
    NodeSelected { node_id: String },
    SearchChanged { query: String },
    BulkToggle { pattern: String, enabled: bool },
}
```

#### 2.4 Search & Filter
- Real-time filtering as user types
- Match node ID, port names, connection targets
- Highlight matching text
- Show/hide non-matching nodes

#### 2.5 Bulk Operations
- "Enable All" / "Disable All" buttons
- Context menu: "Enable all inputs", "Disable all outputs"
- Pattern-based: "Disable all *_log ports"

---

### Phase 3: FlowCanvas Integration (2-3 days)

#### 3.1 Add Enabled/Disabled State to FlowNode
```rust
pub struct FlowNode {
    // ... existing fields ...
    pub enabled: bool,
    pub port_enabled: HashMap<String, bool>,
}
```

#### 3.2 Visual Disabled State
- Disabled nodes: 50% opacity, gray border
- Disabled edges: dashed line, 30% opacity
- Disabled ports: hollow circle instead of filled

**Shader modification for disabled state:**
```rust
// In draw_walk
let opacity = if node.enabled { 1.0 } else { 0.4 };
let header_color = if node.enabled {
    category.header_color()
} else {
    vec4(0.3, 0.3, 0.3, 1.0)
};
```

#### 3.3 Sync with Tree
- Listen for `DataflowTreeAction::NodeToggled`
- Update corresponding FlowNode.enabled
- Redraw canvas

```rust
// In App handle_actions
if let DataflowTreeAction::NodeToggled { node_id, enabled } = action.cast() {
    self.canvas.set_node_enabled(&node_id, enabled);
    self.canvas.redraw(cx);
}
```

#### 3.4 Click-to-Select Sync
- Clicking node in canvas selects in tree
- Clicking node in tree highlights in canvas

---

### Phase 4: Log Panel (2-3 days)

#### 4.1 Create LogPanel Widget
Based on mofa-studio pattern:

```rust
#[derive(Live, LiveHook, Widget)]
pub struct LogPanel {
    #[deref] view: View,
    #[rust] log_entries: Vec<LogEntry>,
    #[rust] level_filter: LogLevel,
    #[rust] node_filter: Option<String>,
    #[rust] search_filter: String,
    #[rust] auto_scroll: bool,
}
```

**Live design:**
```rust
LogPanel = {{LogPanel}} {
    width: Fill, height: Fill
    flow: Down

    // Header with filters
    header = <View> {
        width: Fill, height: Fit
        flow: Down, padding: 8, spacing: 8

        <Label> { text: "System Log" }

        filter_row = <View> {
            flow: Right, spacing: 8
            level_dropdown = <DropDown> {
                labels: ["ALL", "DEBUG", "INFO", "WARN", "ERROR"]
            }
            node_dropdown = <DropDown> {
                labels: ["All Nodes"]  // Populated dynamically
            }
        }

        search_input = <TextInput> {
            empty_text: "Search logs..."
        }
    }

    // Log content
    log_scroll = <ScrollYView> {
        width: Fill, height: Fill
        log_content = <Markdown> {}
    }

    // Footer with controls
    footer = <View> {
        width: Fill, height: 32
        auto_scroll_toggle = <CheckBox> { text: "Auto-scroll" }
        clear_btn = <Button> { text: "Clear" }
        copy_btn = <Button> { text: "Copy" }
    }
}
```

#### 4.2 Log Entry Formatting
```rust
fn format_log_entry(entry: &LogEntry) -> String {
    let level_color = match entry.level {
        LogLevel::Error => "#ff6b6b",
        LogLevel::Warn => "#ffd93d",
        LogLevel::Info => "#6bcb77",
        LogLevel::Debug => "#4d96ff",
    };

    format!(
        "**[{}]** `[{}]` {}\n",
        entry.level,
        entry.node_id,
        entry.message
    )
}
```

#### 4.3 Demo Log Generation
For standalone viewer (no live dora connection):
```rust
fn generate_demo_logs(&mut self) {
    // Parse node IDs from loaded YAML
    // Generate simulated log entries
    // Timer-based log addition for demo
}
```

#### 4.4 Future: Live Dora Integration
- Add optional dora-bridge dependency
- Connect to running dataflow
- Receive real-time logs via shared state

---

### Phase 5: Polish & UX (1-2 days)

#### 5.1 Keyboard Shortcuts
- `Ctrl+F` - Focus search in tree
- `Ctrl+L` - Focus log search
- `Ctrl+E` - Toggle all enabled
- `Space` - Toggle selected node
- `Arrow keys` - Navigate tree

#### 5.2 Status Bar
```
Nodes: 14 (10 enabled) | Edges: 71 (45 active) | [voice-chat.yml]
```

#### 5.3 Toolbar
- File picker for YAML selection
- Zoom controls for canvas
- Layout reset button

#### 5.4 Persistence
- Save enabled/disabled state to file
- Remember panel sizes
- Remember search queries

---

## File Structure

```
examples/dora-viewer/
├── Cargo.toml
├── dataflow/
│   └── voice-chat.yml
└── src/
    ├── main.rs
    ├── app.rs              # Main app, layout
    ├── dataflow_tree.rs    # Tree widget
    ├── log_panel.rs        # Log widget
    ├── yaml_parser.rs      # YAML → tree data
    └── state.rs            # Shared state
```

---

## Dependencies

```toml
[dependencies]
makepad-flow = { path = "../../crates/makepad-flow" }
makepad-widgets = { git = "..." }
serde = { version = "1.0", features = ["derive"] }
serde_yaml = "0.9"

# Optional: for live dora connection
# mofa-dora-bridge = { path = "..." }
```

---

## Timeline Estimate

| Phase | Description | Effort |
|-------|-------------|--------|
| 1 | Layout Foundation | 2-3 days |
| 2 | Dataflow Tree Widget | 3-4 days |
| 3 | FlowCanvas Integration | 2-3 days |
| 4 | Log Panel | 2-3 days |
| 5 | Polish & UX | 1-2 days |
| **Total** | | **10-15 days** |

---

## Key Challenges

1. **Tree Widget Complexity**
   - Makepad FileTree is designed for files, need custom implementation
   - Checkbox + expand/collapse + search filtering
   - Consider PortalList for performance with large trees

2. **State Synchronization**
   - Tree ↔ Canvas must stay in sync
   - Bulk operations must update both
   - Consider using shared state pattern from mofa-studio

3. **YAML Structure Variations**
   - Dora YAML has complex input formats (string vs mapping)
   - Need robust parser that handles all cases
   - Current parser handles basic cases, may need extension

4. **Performance**
   - voice-chat.yml has 14 nodes, 71 edges
   - Real dataflows may be larger (100+ nodes)
   - Use dirty tracking, lazy updates

---

## Next Steps

1. Approve this plan
2. Start with Phase 1 (layout)
3. Iterate on each phase with review checkpoints
