import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // ------------------------------------------------------------ Palette & Theme
    readonly property string fg: "#f4f4f5"
    readonly property string fgSecondary: "#e4e4e7"
    readonly property string muted: "#a1a1aa"
    readonly property string faint: "#71717a"
    readonly property string hairline: "#1affffff"
    readonly property string cardBg: "#0e0e14aa"
    readonly property string searchBg: "#35000000"
    readonly property string itemBg: "#18000000"
    readonly property string itemHoverBg: "#35000000"
    readonly property string itemSelectedBg: "#28d06666"
    readonly property string keycapBg: "#40000000"
    readonly property string keycapBorder: "#26ffffff"
    readonly property string accent: "#d06666"
    readonly property string accentBg: "#33d06666"
    readonly property string accentHover: "#e07878"
    readonly property string warning: "#fbbf24"
    readonly property string errorColor: "#f87171"
    readonly property string successColor: "#34d399"

    // ------------------------------------------------------------ State
    property bool opened: false
    property bool shown: false
    property bool mapped: false
    property string query: ""
    property string activeCategory: "All"
    property int selectedIndex: 0
    property var expandedGroups: ({})

    // Capture state
    property bool isCapturing: false
    property var editingItem: null
    property var heldMods: []
    property string capturedSpec: ""
    property string capturedDisplay: ""

    // Conflict modal state
    property bool showConflictModal: false
    property var conflictData: null

    // Toast state
    property string toastMessage: ""
    property string toastType: "info"
    property bool toastVisible: false

    function showToast(msg, type) {
        toastMessage = msg;
        toastType = type || "info";
        toastVisible = true;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 3500
        onTriggered: root.toastVisible = false
    }

    // ------------------------------------------------------------ Data Source
    FileView {
        id: bindsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/keybinds/keybinds.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    property var keybindsData: {
        try {
            return JSON.parse(bindsFile.text());
        } catch (e) {
            return { total: 0, raw_total: 0, categories: [], groups: [] };
        }
    }

    property var categoryNames: {
        var names = ["All"];
        if (keybindsData && keybindsData.groups) {
            for (var i = 0; i < keybindsData.groups.length; i++) {
                names.push(keybindsData.groups[i].name);
            }
        }
        return names;
    }

    // Flattened items list for navigation and search
    property var visibleItems: {
        var q = query.trim().toLowerCase();
        var cat = activeCategory;
        var out = [];
        var gs = (keybindsData && keybindsData.groups) ? keybindsData.groups : [];

        for (var g = 0; g < gs.length; g++) {
            var grp = gs[g];
            if (cat !== "All" && grp.name !== cat)
                continue;

            var matchingItems = [];
            for (var i = 0; i < grp.items.length; i++) {
                var it = grp.items[i];
                var hay = (it.search || (it.display + " " + it.title + " " + it.category)).toLowerCase();
                if (q !== "" && hay.indexOf(q) === -1)
                    continue;
                matchingItems.push(it);
            }

            if (matchingItems.length > 0) {
                // Category Header Item
                out.push({
                    isHeader: true,
                    name: grp.name,
                    count: matchingItems.length
                });

                for (var j = 0; j < matchingItems.length; j++) {
                    var item = matchingItems[j];
                    out.push({
                        isHeader: false,
                        isGroup: item.is_group || false,
                        data: item
                    });

                    // If it is an expanded group, include sub-items
                    if (item.is_group && expandedGroups[item.id]) {
                        for (var k = 0; k < item.sub_items.length; k++) {
                            out.push({
                                isHeader: false,
                                isSubItem: true,
                                isGroup: false,
                                parentGroupId: item.id,
                                data: item.sub_items[k]
                            });
                        }
                    }
                }
            }
        }
        return out;
    }

    // Selectable items count
    property var selectableIndices: {
        var indices = [];
        for (var i = 0; i < visibleItems.length; i++) {
            if (!visibleItems[i].isHeader)
                indices.push(i);
        }
        return indices;
    }

    // ------------------------------------------------------------ Processes for Conflict & Apply
    Process {
        id: checkConflictProc
        command: []
        property var targetItem: null
        property string testSpec: ""
        property string testDisplay: ""

        stdout: StdioCollector {
            id: conflictOut
        }

        onExited: function(code, status) {
            try {
                var res = JSON.parse(conflictOut.text);
                if (res.conflict) {
                    root.conflictData = {
                        targetItem: checkConflictProc.targetItem,
                        newSpec: checkConflictProc.testSpec,
                        newDisplay: checkConflictProc.testDisplay,
                        conflictingKey: res.conflicting_key,
                        conflictingTitle: res.conflicting_title,
                        conflictingLine: res.conflicting_line_no,
                        targetLine: checkConflictProc.targetItem.line_no
                    };
                    root.showConflictModal = true;
                } else {
                    // No conflict: apply directly!
                    root.executeApply(checkConflictProc.targetItem.line_no, checkConflictProc.testSpec, "replace", null);
                }
            } catch (e) {
                root.showToast("Failed to check shortcut conflicts", "error");
            }
        }
    }

    Process {
        id: applyEditProc
        command: []
        stdout: StdioCollector {
            id: applyOut
        }

        onExited: function(code, status) {
            try {
                var res = JSON.parse(applyOut.text);
                if (res.success) {
                    root.showToast(res.message || "Keybind updated successfully", "success");
                    bindsFile.reload();
                } else {
                    root.showToast(res.message || "Failed to update keybind", "error");
                }
            } catch (e) {
                root.showToast("Error processing configuration change", "error");
            }
        }
    }

    function checkAndApply(item, newSpec, newDisplay) {
        checkConflictProc.targetItem = item;
        checkConflictProc.testSpec = newSpec;
        checkConflictProc.testDisplay = newDisplay;
        checkConflictProc.command = [
            "python3",
            "/usr/local/bin/eva-keybinds-manager",
            "--check-conflict", newSpec,
            "--target-line", String(item.line_no)
        ];
        checkConflictProc.running = true;
    }

    function executeApply(targetLine, newSpec, mode, swapLine) {
        var args = [
            "python3",
            "/usr/local/bin/eva-keybinds-manager",
            "--apply", String(targetLine), newSpec,
            "--mode", mode
        ];
        if (mode === "swap" && swapLine) {
            args.push("--swap-line");
            args.push(String(swapLine));
        }
        applyEditProc.command = args;
        applyEditProc.running = true;
    }

    // ------------------------------------------------------------ Actions & Navigation
    function reset() {
        query = "";
        activeCategory = "All";
        selectedIndex = 0;
        searchInput.text = "";
        isCapturing = false;
        editingItem = null;
        showConflictModal = false;
        conflictData = null;
    }

    function show() {
        reset();
        mapped = true;
        opened = true;
        Qt.callLater(function() {
            shown = true;
            searchInput.forceActiveFocus();
        });
    }

    function hide() {
        if (isCapturing) {
            cancelCapture();
            return;
        }
        shown = false;
        hideTimer.restart();
    }

    function toggle() {
        if (opened)
            hide();
        else
            show();
    }

    Timer {
        id: hideTimer
        interval: 180
        onTriggered: {
            root.mapped = false;
            root.opened = false;
        }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
    }

    // ------------------------------------------------------------ Key Capture Engine
    function startCapture(item) {
        if (!item || !item.editable) return;
        editingItem = item;
        heldMods = [];
        capturedSpec = "";
        capturedDisplay = "";
        isCapturing = true;
        captureFocusItem.forceActiveFocus();
    }

    function cancelCapture() {
        isCapturing = false;
        editingItem = null;
        heldMods = [];
        searchInput.forceActiveFocus();
    }

    function isModifierKey(key) {
        return key === Qt.Key_Control ||
               key === Qt.Key_Shift ||
               key === Qt.Key_Alt ||
               key === Qt.Key_Meta ||
               key === Qt.Key_Super_L ||
               key === Qt.Key_Super_R ||
               key === Qt.Key_AltGr;
    }

    function qtKeyToNiriKey(key, text) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) {
            return String.fromCharCode(key);
        }
        if (key >= Qt.Key_0 && key <= Qt.Key_9) {
            return String.fromCharCode(key);
        }
        if (key >= Qt.Key_F1 && key <= Qt.Key_F12) {
            return "F" + (key - Qt.Key_F1 + 1);
        }
        switch (key) {
            case Qt.Key_Return:
            case Qt.Key_Enter: return "Return";
            case Qt.Key_Space: return "Space";
            case Qt.Key_Tab: return "Tab";
            case Qt.Key_Escape: return "Escape";
            case Qt.Key_Backspace: return "BackSpace";
            case Qt.Key_Delete: return "Delete";
            case Qt.Key_Insert: return "Insert";
            case Qt.Key_Home: return "Home";
            case Qt.Key_End: return "End";
            case Qt.Key_PageUp: return "Page_Up";
            case Qt.Key_PageDown: return "Page_Down";
            case Qt.Key_Left: return "Left";
            case Qt.Key_Right: return "Right";
            case Qt.Key_Up: return "Up";
            case Qt.Key_Down: return "Down";
            case Qt.Key_Slash: return "Slash";
            case Qt.Key_Question: return "Slash";
            case Qt.Key_Backslash: return "backslash";
            case Qt.Key_BracketLeft: return "BracketLeft";
            case Qt.Key_BracketRight: return "BracketRight";
            case Qt.Key_Comma: return "Comma";
            case Qt.Key_Period: return "Period";
            case Qt.Key_Minus: return "Minus";
            case Qt.Key_Equal: return "Equal";
            case Qt.Key_Semicolon: return "semicolon";
            case Qt.Key_Apostrophe: return "apostrophe";
            case Qt.Key_QuoteDbl: return "quotedbl";
            case Qt.Key_AsciiGrave: return "grave";
            case Qt.Key_Print: return "Print";
            default:
                if (text && text.length === 1 && text.charCodeAt(0) >= 32 && text.charCodeAt(0) <= 126) {
                    return text.toUpperCase();
                }
                return "";
        }
    }

    function finishCapture(finalKey) {
        var mods = [];
        if (heldMods.indexOf("Super") !== -1) mods.push("Mod");
        if (heldMods.indexOf("Ctrl") !== -1) mods.push("Ctrl");
        if (heldMods.indexOf("Alt") !== -1) mods.push("Alt");
        if (heldMods.indexOf("Shift") !== -1) mods.push("Shift");

        var spec = mods.concat([finalKey]).join("+");
        var displayCaps = [];
        for (var i = 0; i < mods.length; i++) {
            displayCaps.push(mods[i] === "Mod" ? "Super" : mods[i]);
        }
        var keyDisplay = finalKey;
        if (finalKey === "Return") keyDisplay = "Enter";
        else if (finalKey === "Escape") keyDisplay = "Esc";
        else if (finalKey === "BackSpace") keyDisplay = "Backspace";
        else if (finalKey === "BracketLeft") keyDisplay = "[";
        else if (finalKey === "BracketRight") keyDisplay = "]";
        else if (finalKey === "Slash") keyDisplay = "/";
        displayCaps.push(keyDisplay);

        var displayStr = displayCaps.join(" + ");
        var target = editingItem;

        isCapturing = false;
        editingItem = null;
        heldMods = [];
        searchInput.forceActiveFocus();

        if (target) {
            checkAndApply(target, spec, displayStr);
        }
    }

    // ------------------------------------------------------------ Main Window
    PanelWindow {
        id: win
        visible: root.mapped
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        color: "transparent"
        focusable: root.opened
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "keybinds"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Shortcut inhibitor: Active during key capture so Niri does NOT steal desktop shortcuts!
        ShortcutInhibitor {
            id: inhibitor
            window: win
            enabled: root.isCapturing
        }

        // Invisible focus item for capturing keystrokes
        Item {
            id: captureFocusItem
            anchors.fill: parent
            focus: root.isCapturing

            Keys.onPressed: function(event) {
                if (!root.isCapturing) return;

                if (event.key === Qt.Key_Escape) {
                    root.cancelCapture();
                    event.accepted = true;
                    return;
                }

                // Update held modifiers
                var mods = [];
                if ((event.modifiers & Qt.MetaModifier) || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
                    if (mods.indexOf("Super") === -1) mods.push("Super");
                }
                if ((event.modifiers & Qt.ControlModifier) || event.key === Qt.Key_Control) {
                    if (mods.indexOf("Ctrl") === -1) mods.push("Ctrl");
                }
                if ((event.modifiers & Qt.AltModifier) || event.key === Qt.Key_Alt) {
                    if (mods.indexOf("Alt") === -1) mods.push("Alt");
                }
                if ((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Shift) {
                    if (mods.indexOf("Shift") === -1) mods.push("Shift");
                }
                root.heldMods = mods;

                // If key is only a modifier, do not terminate
                if (root.isModifierKey(event.key)) {
                    event.accepted = true;
                    return;
                }

                // Valid non-modifier key pressed -> Terminate capture immediately!
                var finalKey = root.qtKeyToNiriKey(event.key, event.text);
                if (finalKey !== "") {
                    root.finishCapture(finalKey);
                    event.accepted = true;
                }
            }

            Keys.onReleased: function(event) {
                if (!root.isCapturing) return;
                var mods = [];
                if (event.modifiers & Qt.MetaModifier) mods.push("Super");
                if (event.modifiers & Qt.ControlModifier) mods.push("Ctrl");
                if (event.modifiers & Qt.AltModifier) mods.push("Alt");
                if (event.modifiers & Qt.ShiftModifier) mods.push("Shift");
                root.heldMods = mods;
                event.accepted = true;
            }
        }

        // Dark dimming backdrop
        Rectangle {
            anchors.fill: parent
            color: "#66000000"
            opacity: root.shown ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }
        }

        // Centered Card
        Rectangle {
            id: mainCard
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, 1140)
            height: Math.min(parent.height - 64, 820)
            radius: 16
            color: root.cardBg
            border.width: 1
            border.color: root.hairline
            clip: true

            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.96
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                // absorb clicks inside card
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // ------------------------------------------------ Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 8
                        height: 24
                        radius: 4
                        color: root.accent
                    }

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Keyboard Shortcuts"
                            color: root.fg
                            font.family: "Adwaita Sans"
                            font.pixelSize: 20
                            font.bold: true
                        }
                        Text {
                            text: "Cheatsheet & Interactive Keybind Editor"
                            color: root.muted
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Total Badge
                    Rectangle {
                        radius: 12
                        color: "#50000000"
                        border.width: 1
                        border.color: "#26ffffff"
                        implicitWidth: totalLabel.implicitWidth + 20
                        implicitHeight: 28

                        Text {
                            id: totalLabel
                            anchors.centerIn: parent
                            text: (keybindsData.total || 0) + " shortcuts"
                            color: root.muted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: closeArea.containsMouse ? "#33ffffff" : "#50000000"
                        border.width: 1
                        border.color: "#26ffffff"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: root.fg
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hide()
                        }
                    }
                }

                // ------------------------------------------------ Search Input
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 12
                    color: root.searchBg
                    border.width: 1
                    border.color: searchInput.activeFocus ? root.accent : root.hairline

                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "🔍"
                            font.pixelSize: 14
                            color: root.muted
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            height: 26
                            color: root.fg
                            selectionColor: root.accentBg
                            selectedTextColor: root.fg
                            font.family: "Adwaita Sans"
                            font.pixelSize: 14
                            clip: true

                            onTextChanged: {
                                root.query = text;
                                root.selectedIndex = 0;
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchInput.text === ""
                                text: "Search by shortcut, action, description, or category..."
                                color: root.muted
                                font.family: "Adwaita Sans"
                                font.pixelSize: 14
                            }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Down) {
                                    root.navigateSelection(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.navigateSelection(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageDown) {
                                    root.navigateSelection(6);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageUp) {
                                    root.navigateSelection(-6);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.editSelected();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    if (searchInput.text !== "") {
                                        searchInput.text = "";
                                    } else {
                                        root.hide();
                                    }
                                    event.accepted = true;
                                }
                            }
                        }

                        Rectangle {
                            visible: searchInput.text !== ""
                            width: 20
                            height: 20
                            radius: 10
                            color: clearArea.containsMouse ? "#33ffffff" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: root.muted
                                font.pixelSize: 11
                            }
                            MouseArea {
                                id: clearArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = "";
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }

                        Rectangle {
                            radius: 4
                            color: "#22222a"
                            border.width: 1
                            border.color: root.hairline
                            implicitWidth: escHint.implicitWidth + 8
                            implicitHeight: 20
                            Text {
                                id: escHint
                                anchors.centerIn: parent
                                text: "ESC"
                                color: root.faint
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                    }
                }

                // ------------------------------------------------ Category Pills Bar
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    contentWidth: categoryRow.implicitWidth
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Row {
                        id: categoryRow
                        spacing: 8

                        Repeater {
                            model: root.categoryNames

                            Rectangle {
                                property bool active: root.activeCategory === modelData
                                height: 30
                                radius: 15
                                implicitWidth: catText.implicitWidth + 24
                                color: active ? root.accent : (catMouse.containsMouse ? "#66000000" : "#50000000")
                                border.width: 1
                                border.color: active ? root.accent : "#26ffffff"

                                Text {
                                    id: catText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.active ? "#ffffff" : (catMouse.containsMouse ? root.fg : root.muted)
                                    font.family: "Adwaita Sans"
                                    font.pixelSize: 12
                                    font.bold: parent.active
                                }

                                MouseArea {
                                    id: catMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeCategory = modelData;
                                        root.selectedIndex = 0;
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.hairline
                }

                // ------------------------------------------------ Shortcuts List
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: shortcutsList
                        anchors.fill: parent
                        model: root.visibleItems
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }

                        delegate: Item {
                            width: shortcutsList.width - 12
                            height: modelData.isHeader ? 36 : (modelData.isSubItem ? 42 : 48)

                            // Section Header Delegate
                            Item {
                                visible: modelData.isHeader
                                anchors.fill: parent

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: modelData.isHeader ? modelData.name.toUpperCase() : ""
                                        color: root.accent
                                        font.family: "Adwaita Sans"
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.letterSpacing: 1.5
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: root.hairline
                                    }

                                    Text {
                                        text: modelData.isHeader ? (modelData.count + (modelData.count === 1 ? " shortcut" : " shortcuts")) : ""
                                        color: root.faint
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                    }
                                }
                            }

                            // Shortcut Row Delegate
                            Rectangle {
                                visible: !modelData.isHeader
                                anchors.fill: parent
                                anchors.leftMargin: modelData.isSubItem ? 28 : 0
                                radius: 8
                                property bool isSelected: root.selectedIndex === index
                                property bool isHovered: itemMouse.containsMouse
                                color: isSelected ? root.itemSelectedBg : (isHovered ? root.itemHoverBg : root.itemBg)
                                border.width: 1
                                border.color: isSelected ? root.accent : (isHovered ? "#30ffffff" : root.hairline)

                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 14

                                    // Keycaps Pills
                                    Row {
                                        spacing: 4
                                        Layout.preferredWidth: 260
                                        Layout.alignment: Qt.AlignVCenter

                                        Repeater {
                                            model: modelData.isHeader ? [] : (modelData.data ? modelData.data.caps : [])

                                            Row {
                                                spacing: 4
                                                Rectangle {
                                                    height: 26
                                                    radius: 6
                                                    color: root.keycapBg
                                                    border.width: 1
                                                    border.color: root.keycapBorder
                                                    implicitWidth: capLabel.implicitWidth + 14

                                                    Text {
                                                        id: capLabel
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        color: root.fg
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                    }
                                                }

                                                Text {
                                                    visible: index < (parent.parent.count - 1)
                                                    text: "+"
                                                    color: root.faint
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    font.pixelSize: 11
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }

                                    // Title & Action Description
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.isHeader ? "" : (modelData.data ? modelData.data.title : "")
                                            color: root.fg
                                            font.family: "Adwaita Sans"
                                            font.pixelSize: 13
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.isHeader ? "" : (modelData.data ? modelData.data.action : "")
                                            color: root.muted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Category Pill
                                    Rectangle {
                                        visible: !modelData.isSubItem && !modelData.isHeader
                                        radius: 6
                                        color: "#50000000"
                                        border.width: 1
                                        border.color: "#26ffffff"
                                        implicitWidth: catBadge.implicitWidth + 12
                                        implicitHeight: 22

                                        Text {
                                            id: catBadge
                                            anchors.centerIn: parent
                                            text: modelData.isHeader ? "" : (modelData.data ? modelData.data.category : "")
                                            color: root.muted
                                            font.family: "Adwaita Sans"
                                            font.pixelSize: 10
                                        }
                                    }

                                    // Group Expand Button
                                    Rectangle {
                                        visible: !!modelData.isGroup
                                        radius: 6
                                        color: expandArea.containsMouse ? "#33ffffff" : "#50000000"
                                        border.width: 1
                                        border.color: "#26ffffff"
                                        implicitWidth: expandText.implicitWidth + 14
                                        implicitHeight: 24

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text {
                                                id: expandText
                                                text: (modelData.data && root.expandedGroups[modelData.data.id]) ? "▲ Collapse" : "▼ 9 binds"
                                                color: root.accent
                                                font.family: "Adwaita Sans"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }

                                        MouseArea {
                                            id: expandArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.data) {
                                                    var current = !!root.expandedGroups[modelData.data.id];
                                                    var map = Object.assign({}, root.expandedGroups);
                                                    map[modelData.data.id] = !current;
                                                    root.expandedGroups = map;
                                                }
                                            }
                                        }
                                    }

                                    // Edit Button
                                    Rectangle {
                                        visible: !modelData.isHeader && (modelData.data ? modelData.data.editable : false) && !modelData.isGroup
                                        radius: 6
                                        color: editArea.containsMouse ? root.accent : "#40000000"
                                        border.width: 1
                                        border.color: editArea.containsMouse ? root.accent : "#26ffffff"
                                        implicitWidth: editLabel.implicitWidth + 20
                                        implicitHeight: 24

                                        Text {
                                            id: editLabel
                                            anchors.centerIn: parent
                                            text: "Edit"
                                            color: editArea.containsMouse ? "#ffffff" : root.fgSecondary
                                            font.family: "Adwaita Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: editArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.data)
                                                    root.startCapture(modelData.data);
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedIndex = index;
                                        if (modelData.isGroup && modelData.data) {
                                            var cur = !!root.expandedGroups[modelData.data.id];
                                            var m = Object.assign({}, root.expandedGroups);
                                            m[modelData.data.id] = !cur;
                                            root.expandedGroups = m;
                                        } else if (modelData.data && modelData.data.editable) {
                                            root.startCapture(modelData.data);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty State
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.visibleItems.length === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "🔍 No shortcuts found"
                            color: root.fg
                            font.family: "Adwaita Sans"
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No shortcuts match '" + root.query + "'. Try another keyword or category."
                            color: root.muted
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                        }
                    }
                }

                // ------------------------------------------------ Footer
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.hairline
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24

                    Text {
                        text: "Click any keybind or press Enter to edit"
                        color: root.faint
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 16

                        Text {
                            text: "↑↓ Navigate"
                            color: root.faint
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                        Text {
                            text: "Enter Edit"
                            color: root.faint
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                        Text {
                            text: "Esc Close"
                            color: root.faint
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // ------------------------------------------------ Key Capture Overlay
            Rectangle {
                id: captureOverlay
                visible: root.isCapturing
                anchors.fill: parent
                color: "#f5101015"
                radius: 16

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20
                    width: Math.min(parent.width - 80, 560)

                    // Recording indicator
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: root.accent

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.isCapturing
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            text: "LISTENING FOR NEW SHORTCUT"
                            color: root.accent
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                            font.bold: true
                            font.letterSpacing: 1.5
                        }
                    }

                    // Target action title
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.editingItem ? root.editingItem.title : ""
                        color: root.fg
                        font.family: "Adwaita Sans"
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.editingItem ? ("Current binding: " + root.editingItem.display) : ""
                        color: root.muted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    // Live Keycap Box
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.max(300, keycapRow.implicitWidth + 40)
                        Layout.preferredHeight: 72
                        radius: 12
                        color: "#181820"
                        border.width: 2
                        border.color: root.accent

                        Row {
                            id: keycapRow
                            anchors.centerIn: parent
                            spacing: 8

                            Repeater {
                                model: root.heldMods

                                Row {
                                    spacing: 8
                                    Rectangle {
                                        height: 38
                                        radius: 8
                                        color: root.keycapBg
                                        border.width: 1
                                        border.color: root.accent
                                        implicitWidth: modLabel.implicitWidth + 20

                                        Text {
                                            id: modLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: root.fg
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }

                                    Text {
                                        text: "+"
                                        color: root.muted
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Awaiting final key indicator
                            Rectangle {
                                height: 38
                                radius: 8
                                color: "#252530"
                                border.width: 1
                                border.color: "#404050"
                                implicitWidth: keyPrompt.implicitWidth + 20

                                Text {
                                    id: keyPrompt
                                    anchors.centerIn: parent
                                    text: "Press key..."
                                    color: root.faint
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Press modifiers (Super, Ctrl, Alt, Shift) then any non-modifier key to complete.\nNormal desktop shortcuts are inhibited during capture."
                        color: root.muted
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Cancel button
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 120
                        height: 34
                        radius: 8
                        color: cancelArea.containsMouse ? "#33ffffff" : "#22222a"
                        border.width: 1
                        border.color: root.hairline

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel (Esc)"
                            color: root.fg
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelCapture()
                        }
                    }
                }
            }

            // ------------------------------------------------ Conflict Resolution Modal
            Rectangle {
                id: conflictModal
                visible: root.showConflictModal
                anchors.fill: parent
                color: "#fa101015"
                radius: 16

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 18
                    width: Math.min(parent.width - 80, 520)

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "⚠️ Shortcut Conflict Detected"
                        color: root.warning
                        font.family: "Adwaita Sans"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.conflictData ? ("The shortcut '" + root.conflictData.newDisplay + "' is already assigned to:") : ""
                        color: root.fg
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Conflicting Item Card
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        radius: 8
                        color: "#1c1c24"
                        border.width: 1
                        border.color: "#ffffff1c"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Text {
                                text: root.conflictData ? root.conflictData.conflictingKey : ""
                                color: root.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            Rectangle {
                                width: 1
                                height: 20
                                color: root.hairline
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.conflictData ? root.conflictData.conflictingTitle : ""
                                color: root.fg
                                font.family: "Adwaita Sans"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Choose how to resolve the conflict:"
                        color: root.muted
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        // Replace Button
                        Rectangle {
                            width: 120
                            height: 36
                            radius: 8
                            color: replaceArea.containsMouse ? root.accentHover : root.accent

                            Text {
                                anchors.centerIn: parent
                                text: "Replace"
                                color: "#ffffff"
                                font.family: "Adwaita Sans"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: replaceArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showConflictModal = false;
                                    if (root.conflictData) {
                                        root.executeApply(root.conflictData.targetLine, root.conflictData.newSpec, "replace", null);
                                    }
                                }
                            }
                        }

                        // Swap Button
                        Rectangle {
                            width: 120
                            height: 36
                            radius: 8
                            color: swapArea.containsMouse ? "#3a3a46" : "#282834"
                            border.width: 1
                            border.color: root.hairline

                            Text {
                                anchors.centerIn: parent
                                text: "Swap"
                                color: root.fg
                                font.family: "Adwaita Sans"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: swapArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showConflictModal = false;
                                    if (root.conflictData) {
                                        root.executeApply(root.conflictData.targetLine, root.conflictData.newSpec, "swap", root.conflictData.conflictingLine);
                                    }
                                }
                            }
                        }

                        // Cancel Button
                        Rectangle {
                            width: 120
                            height: 36
                            radius: 8
                            color: conflictCancelArea.containsMouse ? "#33ffffff" : "transparent"
                            border.width: 1
                            border.color: root.hairline

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: root.muted
                                font.family: "Adwaita Sans"
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: conflictCancelArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showConflictModal = false;
                                    root.conflictData = null;
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------ Toast Banner
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: toastRow.implicitWidth + 28
                implicitHeight: 38
                radius: 19
                color: root.toastType === "success" ? "#1b3326" : (root.toastType === "error" ? "#3b1a1a" : "#22222e")
                border.width: 1
                border.color: root.toastType === "success" ? root.successColor : (root.toastType === "error" ? root.errorColor : root.accent)
                visible: root.toastVisible
                opacity: root.toastVisible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                Row {
                    id: toastRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: root.toastType === "success" ? "✓" : (root.toastType === "error" ? "✕" : "ℹ")
                        color: root.toastType === "success" ? root.successColor : (root.toastType === "error" ? root.errorColor : root.accent)
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: root.toastMessage
                        color: root.fg
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }
        }
    }

    function navigateSelection(delta) {
        if (visibleItems.length === 0) return;
        var newIdx = selectedIndex + delta;
        while (newIdx >= 0 && newIdx < visibleItems.length && visibleItems[newIdx].isHeader) {
            newIdx += (delta > 0 ? 1 : -1);
        }
        if (newIdx >= 0 && newIdx < visibleItems.length) {
            selectedIndex = newIdx;
            shortcutsList.positionViewAtIndex(newIdx, ListView.Contain);
        }
    }

    function editSelected() {
        if (selectedIndex >= 0 && selectedIndex < visibleItems.length) {
            var item = visibleItems[selectedIndex];
            if (item && !item.isHeader) {
                if (item.isGroup && item.data) {
                    var cur = !!expandedGroups[item.data.id];
                    var m = Object.assign({}, expandedGroups);
                    m[item.data.id] = !cur;
                    expandedGroups = m;
                } else if (item.data && item.data.editable) {
                    startCapture(item.data);
                }
            }
        }
    }
}
