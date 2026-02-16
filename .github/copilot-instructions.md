# Wallhaven Wallpaper Reborn - Copilot Instructions

## Project Overview

This is a KDE Plasma 6 wallpaper plugin that fetches and displays wallpapers
from wallhaven.cc. It's a port and enhancement of the original
wallhaven-wallpaper-plasma plugin, adding new features like dynamic wallpaper
changes, advanced search capabilities, and system theme integration.

## Technology Stack

- **Framework**: KDE Plasma 6
- **Languages**: QML (UI), JavaScript (logic)
- **APIs**: Wallhaven REST API
- **Dependencies**:
  - Qt 6
  - KDE Frameworks 6 (Kirigami, Plasma Core, KNotification)
  - Qt.labs.platform for system integration

## Project Structure

```
package/
├── metadata.json              # Plugin metadata and configuration
└── contents/
    ├── config/
    │   └── main.xml          # Configuration schema (KConfig XML)
    └── ui/
        ├── main.qml          # Main wallpaper logic and rendering
        └── config.qml        # Settings UI
```

### Key Files

- **`main.qml`**: Core plugin logic including wallpaper fetching, image loading,
  error handling, and user interactions
- **`config.qml`**: Configuration interface with filters, search options, and
  appearance settings
- **`main.xml`**: Configuration schema defining all user settings and their
  defaults

## Architecture & Patterns

### Component Structure

- **WallpaperItem**: Root component that handles wallpaper display and lifecycle
- **Image Components**: Manages current and pending wallpaper images with fade
  transitions
- **Timer**: Handles automatic wallpaper refresh based on user-configured
  interval
- **NetworkRequest**: HTTP requests to Wallhaven API with retry logic
- **Notifications**: System notifications for status updates and errors

### State Management

- Configuration is managed through KDE's configuration system (main.xml + QML
  bindings)
- Local state uses QML properties with reactive bindings
- Image caching via local file storage in `Platform.StandardPaths.CacheLocation`

### Key Features Implementation

1. **Wallpaper Fetching**:
   - Builds API URL from user configuration (query, categories, purity, sorting,
     etc.)
   - Supports advanced query syntax: tags, usernames (`@username`), similar IDs
     (`id:123456`)
   - Multiple tags support: randomly selects one from comma-separated list
   - Retry mechanism for network failures with configurable attempts and delays

2. **Image Display**:
   - Double-buffering: uses `pendingImage` for smooth transitions
   - Fade animations between wallpaper changes
   - Multiple fill modes: fill, fit, stretch, center, tile, scale
   - Blur background option for letterboxing

3. **System Integration**:
   - Dark mode detection: automatically searches for darker wallpapers when
     system is in dark mode
   - Right-click context menu: "Open in Browser" and "Fetch New Wallpaper"
     actions
   - Desktop notifications with user-configurable toggle
   - Respects system color scheme via Kirigami.Theme

## Coding Conventions

### QML Style

- **Indentation**: 4 spaces
- **Property ordering**:
  1. id
  2. Property declarations (grouped by type)
  3. readonly properties
  4. Functions
  5. Signal handlers
  6. Child components

- **Naming**:
  - Properties: camelCase (`currentUrl`, `fillMode`)
  - Functions: camelCase with descriptive verbs (`refreshImage`,
    `fetchWallpaper`)
  - Constants: camelCase for readonly properties
  - Files: lowercase with hyphens for multi-word names

### JavaScript Conventions

- Use template literals for string interpolation
- Prefer `const` and `let` over `var`
- Use arrow functions where appropriate
- Error handling: try-catch blocks with user-friendly error messages
- Logging: Use the `log()` helper function for consistent console output

### Configuration Bindings

- Use `cfg_` prefix for config properties (e.g., `cfg_Query`, `cfg_FillMode`)
- Two-way binding between config.qml and wallpaper.configuration
- Type consistency: match XML schema types

## API Integration

### Wallhaven API

Base URL: `https://wallhaven.cc/api/v1/search`

**Common Parameters**:

- `q`: Search query (tags, username, similar ID)
- `categories`: 3-bit string (general, anime, people)
- `purity`: 3-bit string (SFW, sketchy, NSFW)
- `sorting`: relevance, random, date_added, views, favorites, toplist
- `topRange`: 1d, 3d, 1w, 1M, 3M, 6M, 1y
- `atleast`: Minimum resolution
- `ratios`: Aspect ratios
- `colors`: Color search
- `apikey`: Required for NSFW access and user collections

**Query Syntax**:

- Tags: `landscape,mountains` (comma-separated, one randomly selected)
- Username: `@username`
- Similar: `id:123456`
- Combined: `@user,tag1,tag2,id:123456`

### Error Handling

- Network errors trigger retry mechanism (default: 3 attempts with 5s delay)
- User notifications for both success and failure (when enabled)
- Graceful fallback to last valid wallpaper on persistent errors
- Detailed logging for debugging

## Development Guidelines

### Making Changes

1. **Adding New Configuration Options**:
   - Add entry to `main.xml` with proper type and default
   - Add corresponding `cfg_` property in `config.qml`
   - Bind to UI component in `config.qml`
   - Access via `main.configuration.PropertyName` in `main.qml`

2. **Modifying UI**:
   - Follow Kirigami/Plasma design patterns
   - Use Kirigami components for consistency
   - Ensure proper layout with FormLayout for settings
   - Test in both light and dark themes

3. **API Changes**:
   - Update URL building in `buildUrl()` function
   - Handle new response fields in `onFinished` callback
   - Update error handling if needed
   - Test with various query combinations

4. **Image Handling**:
   - Always use the double-buffering pattern (pendingImage)
   - Ensure proper cleanup of old images
   - Handle all Image.status states (Loading, Ready, Error)
   - Test with slow network conditions

### Testing

- **Manual Testing**:
  - Test all fill modes (fill, fit, stretch, center, tile)
  - Verify dark mode wallpaper fetching
  - Test context menu actions
  - Try various query syntaxes
  - Test network failure scenarios
  - Verify notification settings

- **Configuration Changes**:
  - Ensure settings persist after plasmashell restart
  - Test auto-refresh on config changes
  - Verify all filters work correctly

- **Installation Testing**:
  ```bash
  kpackagetool6 --type Plasma/Wallpaper --upgrade package/
  plasmashell --replace & disown
  ```

## Common Tasks

### Adding a New Filter Option

1. Add to `main.xml`:

```xml
<entry name="NewFilter" type="bool">
  <label>Enable new filter</label>
  <default>false</default>
</entry>
```

2. Add to `config.qml`:

```qml
property bool cfg_NewFilter
```

3. Add UI control:

```qml
CheckBox {
    text: i18nd("plasma_wallpaper_com.plasma.wallpaper.wallhaven", "New Filter")
    checked: cfg_NewFilter
}
```

4. Use in `main.qml`:

```qml
const newFilterValue = main.configuration.NewFilter ? "1" : "0"
```

### Adding a Context Menu Action

Extend the `contextualActions` array in `main.qml`:

```qml
contextualActions: [
    PlasmaCore.Action {
        text: i18n("Action Name")
        icon.name: "icon-name"
        onTriggered: {
            // Action logic
        }
    }
]
```

### Debugging

- Enable console logging: check `journalctl -f` or `.xsession-errors`
- Use `log()` function for consistent output format
- Test with `plasmashell --replace` to see immediate changes
- Check `~/.cache/plasma-wallhaven/` for downloaded wallpapers

## Known Issues & Limitations

1. Cannot be set as lock screen wallpaper due to networking restrictions in lock
   screen context
2. Current wallpaper not shown on first plugin activation
3. Scrollbar visibility issue on window resize

## Resources

- [Wallhaven API Documentation](https://wallhaven.cc/help/api)
- [KDE Plasma Development](https://develop.kde.org/docs/plasma/)
- [QML Documentation](https://doc.qt.io/qt-6/qmlapplications.html)
- [Kirigami Human Interface Guidelines](https://develop.kde.org/hig/)

## License

GPL-2.0-or-later

## Contributors

- Abubakar Yagoub (Current maintainer) - plasma@aolabs.dev
- Link Dupont (Original author) - link@sub-pop.net
