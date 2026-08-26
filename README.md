# seqImgDownloader

**Concurrent image fetching with strictly sequential display order in a UITableView.**

## Problem

When a UITableView cell becomes visible, its image API call fires immediately. All API calls run concurrently, but images must be displayed in strict row order (0 → 1 → 2 → 3…) regardless of which response arrives first.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  UITableView (15 rows)                                  │
│  ┌───────────────────────────────────────────────────┐  │
│  │ willDisplay cell → hitApiToGetImage(row)          │  │
│  │ cellForRowAt     → show image or spinner          │  │
│  └───────────────────────────────────────────────────┘  │
│                         │                               │
│            ┌────────────┼────────────┐                  │
│            ▼            ▼            ▼                  │
│     Task(row 0)   Task(row 1)  Task(row 2)  ...        │
│     (concurrent)  (concurrent) (concurrent)             │
│            │            │            │                  │
│            └────────────┼────────────┘                  │
│                         ▼                               │
│              imagesProcesses: [Int: UIImage]            │
│              (out-of-order buffer / dictionary)         │
│                         │                               │
│                         ▼                               │
│              images: [UIImage]  (ordered array)         │
│              images.count = next expected index         │
│                         │                               │
│                         ▼                               │
│              reloadRows → cell shows image              │
└─────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Type | Purpose |
|---|---|---|
| [`ViewController`](seqImgDownloader/ViewController.swift) | `UIViewController` | Hosts table view, owns all state, drives fetch + ordering logic |
| [`CustomTableCell`](seqImgDownloader/CustomTableCell.swift) | `UITableViewCell` | XIB-based cell with `UIImageView` + `UIActivityIndicatorView` |
| `images: [UIImage]` | Array | Ordered, committed images — `images[i]` is the image for row `i` |
| `imagesProcesses: [Int: UIImage]` | Dictionary | Out-of-order buffer — holds fetched images waiting for their turn |
| `tasks: [Int: Task]` | Dictionary | Tracks in-flight `Task` handles per row for dedup |

## How It Works

### 1. Trigger on Visibility

```swift
func tableView(_ tableView:, willDisplay cell:, forRowAt indexPath:) {
    hitApiToGetImage(forItem: indexPath.row)
}
```

`willDisplay` fires the moment a cell is about to appear on screen, triggering the download for that row immediately.

### 2. Concurrent API Calls

Each call spawns a **detached `Task`** that runs concurrently:

```swift
tasks[forItem] = Task.detached {
    let image = await self.fetchImage(from: urlStr)
    self.imagesProcesses[forItem] = image   // buffer it
}
```

All rows fetch in parallel — row 5 can finish before row 2.

### 3. Duplicate-Request Prevention (Triple Guard)

Before creating a new task, three conditions are checked:

```swift
if images.count > forItem           // ① already committed
   || imagesProcesses[forItem] != nil  // ② already buffered
   || tasks[forItem] != nil            // ③ already in-flight
{ return }
```

This prevents re-fetching on cell reuse/scroll-back.

### 4. Ordered Image Buffering (The Core Trick)

The `imagesProcesses` dictionary has a `didSet` observer that enforces ordering via a **`while` loop** — draining all consecutive ready images in one pass:

```swift
var imagesProcesses: [Int: UIImage] = [:] {
    didSet {
        DispatchQueue.main.async {
            while let image = self.imagesProcesses[self.images.count] {
                let idx = self.images.count
                self.imagesProcesses[idx] = nil
                self.images.append(image)
                self.tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .automatic)
            }
        }
    }
}
```

**How ordering is enforced:**

- `images.count` always equals the next index we *need* (e.g., if 0 and 1 are committed, `images.count == 2`).
- When a download finishes and sets `imagesProcesses[row] = image`, `didSet` fires.
- The `while` loop checks: *"Is the image for the next expected index available?"*
  - **Yes** → commit it, advance `images.count`, and loop again to flush the next consecutive image.
  - **No** → stop; the image stays buffered until earlier rows arrive.

**Example:** If rows finish in order 3, 1, 2, 0:

| Event | `imagesProcesses` buffer | `images` (committed) | Display |
|---|---|---|---|
| Row 3 arrives | `{3: img}` | `[]` | — |
| Row 1 arrives | `{1: img, 3: img}` | `[]` | — |
| Row 2 arrives | `{1: img, 2: img, 3: img}` | `[]` | — |
| Row 0 arrives | `while` loop drains 0→1→2→3 | `[img0…img3]` | All 4 rows shown in order |

The `while` loop ensures that when row 0 finally arrives, all buffered consecutive images (1, 2, 3) are flushed immediately in a single pass.