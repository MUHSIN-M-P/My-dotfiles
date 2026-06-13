# Noctalia Official To-Do List Plugin

The system has been configured to use the official Noctalia To-Do List plugin (`plugin:todo`) rather than a custom implementation, ensuring complete shell stability and layout compatibility.

## How to Add To-Do Items

The official plugin separates the desktop view (lightweight display and completion) from the management view (adding, renaming, prioritizing, and reordering). There are two official ways to add items to your list:

### 1. Via the Sliding Management Panel (GUI)

The main management interface is the sliding **To-Do Panel**:
- **From Control Center**: Open the Control Center (top-right of your screen) and click on the **To-Do List** icon (represented by a clipboard check). This will slide out the To-Do Panel.
- **Adding a Task**: At the top of the panel, type your task in the input box, select the priority:
  - **H** (High Priority - Red Indicator)
  - **M** (Medium Priority - Blue/Primary Indicator)
  - **L** (Low Priority - Grey Indicator)
- Press **Enter** or click the `+` button to add the item.

### 2. Via Quickshell IPC (CLI)

The plugin provides full IPC integration, allowing you to add tasks programmatically from any terminal or custom script:

```bash
# Add a task to the default category (Medium priority)
qs -c noctalia-shell ipc call plugin:todo addTodoDefault "Buy groceries"

# Add a task with specific priority and page ID
# Usage: addTodo "Task text" <pageId> "priority"
qs -c noctalia-shell ipc call plugin:todo addTodo "Read paper" 0 "high"
```

## Features

- **Desktop Widget**: View active tasks and check them off directly on your desktop.
- **Category Pages**: Organize tasks across different pages (e.g. Work, Personal).
- **Drag & Drop Reordering**: Drag items by the handle in the sliding panel to prioritize them.
- **Exporting**: Export your tasks to Markdown or JSON from the panel header.
