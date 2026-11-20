# Eva Linux Keybind Cheatsheet & Interactive Editor

Eva Linux features a native Wayland keybinding cheatsheet and live editor overlay built on **Quickshell** and **Niri**.

---

## Features

1. **Hotkey Activation**: Press `Super + Shift + /` anywhere on the desktop to instantly toggle the overlay.
2. **Instant Search**: Type directly into the search bar to filter shortcuts by key, action name, or category.
3. **Repetitive Grouping**: Repetitive key patterns (such as `Super + 1–9` for switching workspaces) are automatically condensed into clean expandable groups.
4. **Interactive Keybind Editing**:
   - Click the **Edit** button next to any shortcut.
   - Press the new key combination directly on your physical keyboard.
   - The conflict manager verifies whether the shortcut is already in use.
   - If a conflict is found, choose between **Replace** or **Swap**.
   - The editor runs `niri validate` in a sandbox before saving to `~/.config/niri/keybinds.kdl`.
   - If validation passes, Niri automatically reloads configuration without restarting your session.
   - If validation fails, changes are automatically rolled back.
5. **Frosted Glass Blur**: Niri applies a hardware-accelerated frosted glass blur layer behind the popup.
