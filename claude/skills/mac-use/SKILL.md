---
name: mac-use
description: macOS automation using AppleScript and JavaScript for Automation (JXA). Use when automating macOS apps, controlling system features, scripting applications like Music, Notes, Finder, Safari, or any scriptable app. Use when the user asks about currently opened screens, UI elements, or visible content in any macOS app.
allowed-tools: Bash(osascript:*), Bash(sdef:*), Read
---

# AppleScript & JXA Automation

## Overview

Use JavaScript for Automation (JXA) via `osascript -l JavaScript` for macOS automation. JXA is preferred over AppleScript for its familiar syntax and better data handling.

## Getting App Information

### Get scripting dictionary
```bash
sdef /Applications/AppName.app
sdef /System/Applications/Music.app
```

### Get app properties
```javascript
osascript -l JavaScript -e 'Application("AppName").properties()'
```

## Core Patterns

### Basic app interaction
```javascript
osascript -l JavaScript -e '
const app = Application("AppName")
app.includeStandardAdditions = true
// ... operations
'
```

### Multi-line scripts
```javascript
osascript -l JavaScript -e '
const finder = Application("Finder")
const selection = finder.selection()
selection.map(f => f.name())
'
```

## Common Operations

### File Operations
```javascript
// Read file
const app = Application.currentApplication()
app.includeStandardAdditions = true
app.read(Path("/path/to/file"))

// Write file
app.write("content", {to: Path("/path/to/file")})

// Open file for access
app.openForAccess(Path("/path"))
```

### Finder
```javascript
osascript -l JavaScript -e '
const finder = Application("Finder")

// Get selected files
const selection = finder.selection()
selection.map(f => ({name: f.name(), path: f.url()}))

// Create folder
finder.make({new: "folder", at: finder.desktop, withProperties: {name: "New Folder"}})

// Move file
finder.move(finder.files["test.txt"], {to: finder.folders["Documents"]})
'
```

### Music App
```javascript
osascript -l JavaScript -e '
const music = Application("Music")

// Search library
const lib = music.playlists.byName("Library")
const results = lib.search({for: "love"})
results.map(t => ({
  name: t.name(),
  artist: t.artist(),
  album: t.album(),
  duration: t.duration()
}))

// Playback control
music.play()
music.pause()
music.nextTrack()
music.previousTrack()

// Current track
const track = music.currentTrack
({name: track.name(), artist: track.artist()})
'
```

### Music App - Get Currently Opened Screen/View
Use System Events to inspect the current UI state and visible content:
```javascript
osascript -l JavaScript -e '
const se = Application("System Events");
const music = se.processes["Music"];

// Get main content title (artist/album/playlist name being viewed)
const mainContent = music.windows[0].splitterGroups[0].scrollAreas[1].lists[0].lists[0].uiElements[0].staticTexts[0];
mainContent.value();
'
```

### Music App - List Items from a UI Section
```javascript
osascript -l JavaScript -e '
const se = Application("System Events");
const music = se.processes["Music"];

// Get Singles & EPs list (list index 4 in main content)
const singlesEPsList = music.windows[0].splitterGroups[0].scrollAreas[1].lists[0].lists[4];
const groups = singlesEPsList.groups();
const albums = [];

for (const group of groups.slice(1)) {
    try {
        const btns = group.buttons();
        if (btns.length > 0) {
            const name = btns[0].name();
            if (name && name !== "1") {
                albums.push(name);
            }
        }
    } catch (e) {}
}

albums.join("\n");
'
```

### Music App - Get Entire Window Contents (for exploration)
```javascript
osascript -l JavaScript -e '
const se = Application("System Events");
const music = se.processes["Music"];
music.windows[0].entireContents();
'
```

### Play all tracks by artist
```javascript
osascript -l JavaScript -e '
const music = Application("Music")

// Search for artist
const lib = music.playlists.byName("Library")
const results = lib.search({for: "Lab'\''s Cloud"})

// Get unique artists from results
const artists = [...new Set(results.map(t => t.artist()))]

// Find the exact artist match
const targetArtist = artists.find(a => a === "Lab'\''s Cloud")

if (targetArtist) {
  // Filter tracks by the selected artist
  const artistTracks = results.filter(t => t.artist() === targetArtist)

  if (artistTracks.length > 0) {
    // Play first track and queue the rest
    music.play(artistTracks[0])

    // Queue remaining tracks
    for (let i = 1; i < artistTracks.length; i++) {
      music.playPlaylist(lib, false)
    }

    "Now playing " + targetArtist + " - queued " + artistTracks.length + " tracks"
  }
} else {
  "Artist not found"
}
'
```

### Notes
```javascript
osascript -l JavaScript -e '
const notes = Application("Notes")

// Create note
notes.make({new: "note", withProperties: {body: "Hello World"}})

// List folders
notes.folders().map(f => f.name())

// Create note in specific folder
const folder = notes.folders.byName("Notes")
notes.make({new: "note", at: folder, withProperties: {name: "Title", body: "Content"}})
'
```

### Safari
```javascript
osascript -l JavaScript -e '
const safari = Application("Safari")

// Get current URL
safari.windows[0].currentTab.url()

// Get all tab URLs
safari.windows[0].tabs().map(t => ({name: t.name(), url: t.url()}))

// Open URL
safari.openLocation("https://example.com")

// Find existing tab or open new one
const Safari = Application("Safari")
Safari.activate()

let foundHackerNews = false
const frontmostWindow = Safari.windows[0]

// Iterate over all tabs in the frontmost window
for (let i = 0; i < frontmostWindow.tabs.length; i++) {
  const tab = frontmostWindow.tabs[i]
  const tabUrl = tab.url()

  if (tabUrl && tabUrl.includes("news.ycombinator.com")) {
    frontmostWindow.currentTab = tab
    foundHackerNews = true
    break
  }
}

// If Hacker News was not found, open it in a new tab
if (!foundHackerNews) {
  const newTab = Safari.Tab({url: "https://news.ycombinator.com"})
  frontmostWindow.tabs.push(newTab)
  frontmostWindow.currentTab = newTab
}

// Execute JavaScript in page
safari.doJavaScript("document.title", {in: safari.windows[0].currentTab})
'
```

### System Events (UI Automation)
```javascript
osascript -l JavaScript -e '
const se = Application("System Events")

// List running apps
se.processes().map(p => p.name())

// Click menu item
const proc = se.processes.byName("Finder")
proc.menuBars[0].menuBarItems.byName("File").menus[0].menuItems.byName("New Finder Window").click()

// Keystroke
se.keystroke("v", {using: "command down"})
se.keyCode(36) // Return key
'
```

### Notifications
```javascript
osascript -l JavaScript -e '
const app = Application.currentApplication()
app.includeStandardAdditions = true
app.displayNotification("Body text", {
  withTitle: "Title",
  subtitle: "Subtitle",
  soundName: "Frog"
})
'
```

### Dialogs
```javascript
osascript -l JavaScript -e '
const app = Application.currentApplication()
app.includeStandardAdditions = true

// Alert
app.displayAlert("Title", {message: "Details", buttons: ["OK", "Cancel"]})

// Choose file
app.chooseFile({withPrompt: "Select a file"})

// Choose folder
app.chooseFolder({withPrompt: "Select folder"})

// Text input
app.displayDialog("Enter name:", {defaultAnswer: ""})
'
```

### Clipboard
```javascript
osascript -l JavaScript -e '
const app = Application.currentApplication()
app.includeStandardAdditions = true

// Get clipboard
app.theClipboard()

// Set clipboard
app.setTheClipboardTo("New content")
'
```

### Calendar
```javascript
osascript -l JavaScript -e '
const cal = Application("Calendar")

// List calendars
cal.calendars().map(c => c.name())

// Create event
const calendar = cal.calendars.byName("Home")
cal.Event({
  summary: "Meeting",
  startDate: new Date("2024-01-15T10:00:00"),
  endDate: new Date("2024-01-15T11:00:00")
}).make({at: calendar})
'
```

### Reminders
```javascript
osascript -l JavaScript -e '
const rem = Application("Reminders")

// List reminder lists
rem.lists().map(l => l.name())

// Create reminder
const list = rem.lists.byName("Reminders")
rem.Reminder({name: "Buy groceries", dueDate: new Date()}).make({at: list})
'
```

## Tips

1. **Always check sdef first** - Run `sdef /path/to/app.app` to see available commands
2. **Use properties()** - Quick way to see what's accessible on any object
3. **Enable standard additions** - `app.includeStandardAdditions = true` for dialogs, file ops
4. **Handle arrays** - JXA returns special arrays; use `.map()` to extract values
5. **Debugging** - Add `console.log()` and run with `osascript -l JavaScript script.js`

## Error Handling

```javascript
osascript -l JavaScript -e '
try {
  const music = Application("Music")
  music.currentTrack.name()
} catch(e) {
  "No track playing"
}
'
```
