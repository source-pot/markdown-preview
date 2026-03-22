# mdview

A native macOS markdown previewer with syntax highlighting and live reload.

## Features

- Native macOS app built with Swift and SwiftUI
- Syntax highlighting for code blocks (highlight.js)
- Light, Dark, and Auto (system) themes
- Directory browsing with sidebar file tree
- Auto-refresh when files or directories change on disk
- Serif typography for headings
- GitHub-inspired styling
- Launches as a standalone GUI app (detaches from terminal)

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later

## Building

```bash
# Debug build
swift build

# Release build (recommended for installation)
swift build -c release
```

The release binary is located at `.build/release/mdview`.

## Installation

Build and install in one step:

```bash
./install.sh
```

This builds the release binary and copies it to `/usr/local/bin`.

## Usage

### Open a markdown file

```bash
mdview document.md
```

The app launches as a standalone GUI window and returns control to the terminal immediately.

### Open a directory

```bash
mdview docs/
```

Opens a sidebar showing all markdown files and subdirectories. Click a file to preview it.

### Open via file dialog

Run without arguments to show a file/directory picker:

```bash
mdview
```

### Workflow

- The preview window opens with the rendered markdown
- Edit the file in your editor; the preview auto-refreshes on save
- In directory mode, the sidebar updates automatically when files are added or removed
- Close the window to return to the file picker
- Cancel the file picker to quit the app

## Theme Configuration

Access themes via the menu bar:

**View > Theme**
- **Light** - Light background with dark text
- **Dark** - Dark background with light text
- **Auto (System)** - Follows macOS appearance setting

Theme preference is saved and persists across sessions.

## Project Structure

```
mdview/
├── Package.swift
├── Sources/mdview/
│   ├── main.swift              # CLI entry point (forks to detach from terminal)
│   ├── MdviewApp.swift         # App delegate and window management
│   ├── AppState.swift          # Observable state
│   ├── ContentView.swift       # WKWebView wrapper with optional sidebar
│   ├── DirectoryNode.swift     # File tree data model
│   ├── DirectoryBrowser.swift  # Sidebar directory browser view
│   ├── MarkdownRenderer.swift  # Markdown to HTML conversion
│   ├── FileWatcher.swift       # File change monitoring
│   ├── DirectoryWatcher.swift  # Directory change monitoring
│   ├── ThemeManager.swift      # Theme preferences
│   └── Resources/
│       ├── style.css           # Light/dark theme styles
│       └── highlight.min.js    # Syntax highlighting
```

## Dependencies

- [swift-markdown](https://github.com/apple/swift-markdown) - Apple's markdown parser
- [highlight.js](https://highlightjs.org/) - Syntax highlighting (bundled)

## License

MIT
