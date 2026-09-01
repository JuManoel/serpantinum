//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../singletons"
import "../../"
import "../../reusables"

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property bool keepAlive: inNoteView && isEditing
    property bool isEditing: false
    property bool inNoteView: false
    property string iconFont: "Font Awesome 6 Free Solid"
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    property string previewHtml: ""
    property bool useQtFallback: false
    property string activeNoteTitle: ""

    function s(val) { return typeof scaleFunc === "function" ? scaleFunc(val) : val; }

    property real baseW: s(380)
    property real baseL: s(420)
    property real preferredWidth: (safeActiveEdge === "bottom" || safeActiveEdge === "top") ? baseL + 50 : baseW
    property real preferredExtraLength: (safeActiveEdge === "bottom" || safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (safeActiveEdge === "right") return 180;
        if (safeActiveEdge === "bottom") return 90;
        if (safeActiveEdge === "top") return -90;
        return 0;
    }

    property color cBase: ThemeBackend.base
    property color cMantle: ThemeBackend.mantle
    property color cSurface0: ThemeBackend.surface0
    property color cSurface1: ThemeBackend.surface1
    property color cText: ThemeBackend.text
    property color cSubtext0: ThemeBackend.subtext0
    property color cMauve: ThemeBackend.mauve
    property color cCrust: ThemeBackend.crust

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    readonly property string notesPath: Caching.getStateDir("notepad") + "/notes.json"
    readonly property string renderInputPath: Caching.getRunDir("notepad") + "/render_in.json"
    readonly property string mdRenderScript: Caching.serpantinumDir + "/scripts/notepad/md_render.py"

    property var notes: []
    property string activeId: ""
    property bool loaded: false
    property bool suppressSave: false

    property var interceptedShortcuts: {
        if (!inNoteView || !isEditing || !editorArea.activeFocus) return [];
        return ["Return", "Enter", "Left", "Right", "Up", "Down", "Tab", "Shift+Tab", "Backspace"];
    }

    FileView {
        id: notesFile
        path: root.notesPath
        blockLoading: true
        watchChanges: false
    }

    FileView {
        id: renderInputFile
        path: root.renderInputPath
    }

    Timer {
        id: saveTimer
        interval: 400
        repeat: false
        onTriggered: root.persistNotes()
    }

    Timer {
        id: renderTimer
        interval: 120
        repeat: false
        onTriggered: root.requestRender()
    }

    Process {
        id: renderProc
        command: ["python3", root.mdRenderScript, root.renderInputPath]
        stdout: StdioCollector {
            onStreamFinished: {
                let html = this.text.trim();
                if (html !== "") {
                    root.previewHtml = html;
                    root.useQtFallback = false;
                } else {
                    root.applyQtFallback();
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.applyQtFallback();
        }
    }

    function colorToHex(c) {
        if (!c) return "#ffffff";
        function channel(v) {
            let n = Math.round(Math.max(0, Math.min(1, v)) * 255);
            let h = n.toString(16);
            return h.length === 1 ? "0" + h : h;
        }
        return "#" + channel(c.r) + channel(c.g) + channel(c.b);
    }

    function themePayload() {
        return {
            text: colorToHex(cText),
            base: colorToHex(cBase),
            mantle: colorToHex(cMantle),
            mauve: colorToHex(cMauve),
            surface0: colorToHex(cSurface0),
            subtext0: colorToHex(cSubtext0),
            fontFamily: ThemeBackend.fontFamily
        };
    }

    function newId() {
        return "n_" + Date.now().toString(36) + "_" + Math.floor(Math.random() * 1e6).toString(36);
    }

    function stripMarkdown(line) {
        if (!line) return "";
        line = line.replace(/^#+\s*/, "");
        line = line.replace(/\*\*(.*?)\*\*/g, "$1");
        line = line.replace(/\*(.*?)\*/g, "$1");
        line = line.replace(/`(.*?)`/g, "$1");
        line = line.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");
        return line.trim();
    }

    function noteTitle(note) {
        if (!note || !note.content) return I18n.t("quickactions.notepad.untitled");
        let lines = note.content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let line = root.stripMarkdown(lines[i]);
            if (line !== "") return line;
        }
        return I18n.t("quickactions.notepad.untitled");
    }

    function syncActiveNoteTitle() {
        root.activeNoteTitle = root.noteTitle(root.activeNote());
    }

    function activeNote() {
        for (let i = 0; i < root.notes.length; i++)
            if (root.notes[i].id === root.activeId) return root.notes[i];
        return null;
    }

    function activeIndex() {
        for (let i = 0; i < root.notes.length; i++)
            if (root.notes[i].id === root.activeId) return i;
        return -1;
    }

    function repopulateModel() {
        notesModel.clear();
        for (let i = 0; i < root.notes.length; i++)
            notesModel.append(root.notes[i]);
    }

    function loadFromDisk() {
        let raw = notesFile.text();
        if (!raw || raw.trim() === "") {
            root.notes = [];
            root.activeId = "";
            root.loaded = true;
            return;
        }
        try {
            let data = JSON.parse(raw);
            root.notes = Array.isArray(data.notes) ? data.notes : [];
            root.activeId = data.activeId || "";
            if (root.activeId && !root.activeNote()) root.activeId = root.notes.length > 0 ? root.notes[0].id : "";
        } catch (e) {
            root.notes = [];
            root.activeId = "";
        }
        root.loaded = true;
        root.syncActiveNoteTitle();
    }

    function persistNotes() {
        if (!root.loaded || root.suppressSave) return;
        let payload = JSON.stringify({
            activeId: root.activeId,
            notes: root.notes
        }, null, 2);
        notesFile.setText(payload);
    }

    function scheduleSave() {
        saveTimer.restart();
    }

    function scheduleRender() {
        if (!inNoteView || isEditing) return;
        renderTimer.restart();
    }

    function requestRender() {
        if (!inNoteView || isEditing) return;
        let note = root.activeNote();
        if (!note) return;
        let payload = JSON.stringify({
            markdown: note.content || "",
            theme: themePayload(),
            emptyHint: I18n.t("quickactions.notepad.tap_to_write")
        });
        renderInputFile.setText(payload);
        renderProc.running = false;
        renderProc.running = true;
    }

    function applyQtFallback() {
        root.useQtFallback = true;
        let note = root.activeNote();
        previewArea.text = note && note.content ? note.content : "";
    }

    function updateActiveContent(text) {
        let note = root.activeNote();
        if (!note) return;
        note.content = text;
        note.title = root.noteTitle(note);
        note.updatedAt = Date.now();
        let idx = root.activeIndex();
        if (idx >= 0) notesModel.set(idx, note);
        root.syncActiveNoteTitle();
        root.scheduleSave();
    }

    function beginEditing() {
        root.isEditing = true;
        root.suppressSave = true;
        editorArea.text = root.activeNote() ? (root.activeNote().content || "") : "";
        root.suppressSave = false;
        Qt.callLater(() => editorArea.forceActiveFocus());
    }

    function finishEditing() {
        if (!root.isEditing) return;
        root.updateActiveContent(editorArea.text);
        root.isEditing = false;
        root.scheduleRender();
    }

    function openNote(id) {
        root.activeId = id;
        root.inNoteView = true;
        root.isEditing = false;
        root.syncActiveNoteTitle();
        root.scheduleRender();
    }

    function closeNoteView() {
        root.finishEditing();
        root.persistNotes();
        root.inNoteView = false;
        root.isEditing = false;
    }

    function createNote() {
        let note = {
            id: root.newId(),
            title: I18n.t("quickactions.notepad.untitled"),
            content: "",
            updatedAt: Date.now()
        };
        root.notes.unshift(note);
        notesModel.insert(0, note);
        root.openNote(note.id);
        root.beginEditing();
    }

    function deleteNoteAtIndex(idx) {
        if (idx < 0 || idx >= root.notes.length) return;
        let removedId = root.notes[idx].id;
        root.notes.splice(idx, 1);
        notesModel.remove(idx);
        if (root.activeId === removedId) {
            if (root.notes.length === 0) {
                root.activeId = "";
                root.inNoteView = false;
                root.isEditing = false;
            } else {
                root.activeId = root.notes[Math.min(idx, root.notes.length - 1)].id;
            }
        }
        root.persistNotes();
    }

    function selectNote(id) {
        root.finishEditing();
        root.openNote(id);
    }

    ListModel { id: notesModel }

    onIsActiveTabChanged: {
        if (!isActiveTab && isEditing) root.finishEditing();
    }

    Component.onCompleted: {
        loadFromDisk();
        repopulateModel();
        inNoteView = false;
    }

    Component.onDestruction: persistNotes()

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true

        Rectangle {
            anchors.fill: parent
            color: root.cMantle
            radius: ThemeBackend.borderRadius
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(8)
            visible: !root.inNoteView
            opacity: root.inNoteView ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 180 } }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Text {
                    text: I18n.t("quickactions.notepad.title")
                    font.family: ThemeBackend.fontFamily
                    font.bold: true
                    font.pixelSize: root.s(14)
                    color: root.cText
                }

                Item { Layout.fillWidth: true }

                ClickButton {
                    buttonText: I18n.t("quickactions.notepad.new")
                    onTriggered: root.createNote()
                }

                DeleteButton {
                    Layout.preferredWidth: root.s(30)
                    Layout.preferredHeight: root.s(30)
                    enabled: root.activeId !== ""
                    onTriggered: root.deleteNoteAtIndex(root.activeIndex());
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: notesList
                    anchors.fill: parent
                    spacing: root.s(4)
                    model: notesModel
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Text {
                        anchors.centerIn: parent
                        visible: notesModel.count === 0
                        text: I18n.t("quickactions.notepad.empty_list")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(11)
                        color: root.cSubtext0
                        horizontalAlignment: Text.AlignHCenter
                    }

                    delegate: Item {
                        id: noteDelegateWrapper
                        width: notesList.width
                        height: noteDelegateCard.height

                        property bool isSelected: model.id === root.activeId
                        property real dragX: 0
                        property bool isDismissing: false

                        scale: (noteCardMa.pressed && !noteCardMa.draggingH) ? 0.98 : 1.0
                        Behavior on scale {
                            enabled: !noteCardMa.draggingH
                            NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
                        }

                        NumberAnimation {
                            id: noteResetAnim
                            target: noteDelegateWrapper
                            property: "dragX"
                            from: noteDelegateWrapper.dragX
                            to: 0
                            duration: 200
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            id: noteDismissAnim
                            target: noteDelegateWrapper
                            property: "dragX"
                            from: noteDelegateWrapper.dragX
                            to: 0
                            duration: 200
                            easing.type: Easing.OutQuad
                            onFinished: root.deleteNoteAtIndex(index)
                        }

                        Rectangle {
                            id: noteDelegateCard
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: root.s(52)
                            radius: Math.min(ThemeBackend.borderRadius, root.s(12))
                            color: {
                                if (noteDelegateWrapper.isSelected) return root.cMauve;
                                return noteCardMa.containsMouse && !noteCardMa.draggingH ? Qt.lighter(root.cSurface1, 1.04) : root.cSurface1;
                            }
                            clip: true

                            transform: Translate { x: noteDelegateWrapper.dragX }
                            opacity: Math.max(0.0, 1.0 - (Math.abs(noteDelegateWrapper.dragX) / (noteDelegateCard.width * 0.75)))

                            Behavior on color {
                                enabled: !noteCardMa.draggingH
                                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: root.s(12)
                                anchors.rightMargin: root.s(12)
                                anchors.topMargin: root.s(8)
                                anchors.bottomMargin: root.s(8)
                                spacing: root.s(2)

                                Text {
                                    Layout.fillWidth: true
                                    text: root.noteTitle({ content: model.content, title: model.title })
                                    font.family: ThemeBackend.fontFamily
                                    font.bold: noteDelegateWrapper.isSelected
                                    font.pixelSize: root.s(12)
                                    color: noteDelegateWrapper.isSelected ? root.cCrust : root.cText
                                    elide: Text.ElideRight

                                    Behavior on color {
                                        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        if (!model.content || model.content.trim() === "") return I18n.t("quickactions.notepad.tap_to_write");
                                        let preview = root.stripMarkdown(model.content.replace(/\n/g, " ").trim());
                                        return preview.length > 60 ? preview.substring(0, 60) + "…" : preview;
                                    }
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(11)
                                    color: noteDelegateWrapper.isSelected
                                        ? root.alpha(root.cCrust, 0.85)
                                        : root.cSubtext0
                                    elide: Text.ElideRight
                                    maximumLineCount: 1

                                    Behavior on color {
                                        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: model.updatedAt > 0
                                    text: {
                                        let d = new Date(model.updatedAt);
                                        return d.toLocaleDateString() + " " + d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
                                    }
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(8)
                                    color: noteDelegateWrapper.isSelected
                                        ? root.alpha(root.cCrust, 0.65)
                                        : root.alpha(root.cSubtext0, 0.75)
                                    elide: Text.ElideRight

                                    Behavior on color {
                                        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                    }
                                }
                            }

                            MouseArea {
                                id: noteCardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !noteDelegateWrapper.isDismissing
                                cursorShape: Qt.PointingHandCursor

                                property real startRootX: 0
                                property real startRootY: 0
                                property bool draggingH: false

                                onPressed: (mouse) => {
                                    let pt = mapToItem(notesList, mouse.x, mouse.y);
                                    startRootX = pt.x;
                                    startRootY = pt.y;
                                    draggingH = false;
                                    noteResetAnim.stop();
                                }

                                onPositionChanged: (mouse) => {
                                    if (!pressed) return;
                                    let pt = mapToItem(notesList, mouse.x, mouse.y);
                                    let dx = pt.x - startRootX;
                                    let dy = pt.y - startRootY;

                                    if (!draggingH) {
                                        if (Math.abs(dx) > root.s(6) && Math.abs(dx) > Math.abs(dy)) {
                                            draggingH = true;
                                            noteCardMa.preventStealing = true;
                                        }
                                    }

                                    if (draggingH) {
                                        noteDelegateWrapper.dragX = dx;
                                    }
                                }

                                onReleased: (mouse) => {
                                    noteCardMa.preventStealing = false;
                                    if (draggingH) {
                                        let threshold = noteDelegateCard.width * 0.18;
                                        if (Math.abs(noteDelegateWrapper.dragX) > threshold) {
                                            noteDelegateWrapper.isDismissing = true;
                                            noteDismissAnim.from = noteDelegateWrapper.dragX;
                                            noteDismissAnim.to = noteDelegateWrapper.dragX > 0
                                                ? noteDelegateCard.width * 1.2
                                                : -noteDelegateCard.width * 1.2;
                                            noteDismissAnim.start();
                                        } else {
                                            noteResetAnim.from = noteDelegateWrapper.dragX;
                                            noteResetAnim.start();
                                        }
                                        draggingH = false;
                                    } else {
                                        root.activeId = model.id;
                                        root.selectNote(model.id);
                                    }
                                }

                                onCanceled: {
                                    noteCardMa.preventStealing = false;
                                    if (draggingH) {
                                        noteResetAnim.from = noteDelegateWrapper.dragX;
                                        noteResetAnim.start();
                                        draggingH = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(12)
            spacing: root.s(8)
            visible: root.inNoteView
            opacity: root.inNoteView ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(6)

                ClickButton {
                    buttonText: I18n.t("quickactions.notepad.back_to_list")
                    onTriggered: root.closeNoteView()
                }

                Text {
                    Layout.fillWidth: true
                    text: root.activeNoteTitle
                    font.family: ThemeBackend.fontFamily
                    font.bold: true
                    font.pixelSize: root.s(12)
                    color: root.cText
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: ThemeBackend.borderRadius
                color: root.cBase
                border.width: 1
                border.color: root.isEditing ? root.cMauve : root.cSurface1
                clip: true

                // --- PREVIEW (rendered markdown) ---
                Item {
                    id: previewLayer
                    anchors.fill: parent
                    visible: !root.isEditing
                    opacity: root.isEditing ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Flickable {
                        id: previewFlickable
                        anchors.fill: parent
                        anchors.margins: root.s(8)
                        contentWidth: width
                        contentHeight: Math.max(height, previewArea.paintedHeight + root.s(48))
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: previewArea
                            width: parent.width
                            readOnly: true
                            selectByMouse: false
                            focus: false
                            textFormat: root.useQtFallback ? TextEdit.MarkdownText : TextEdit.RichText
                            text: root.useQtFallback
                                ? ((root.activeNote() && root.activeNote().content) ? root.activeNote().content : "")
                                : root.previewHtml
                            color: root.cText
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            wrapMode: TextEdit.Wrap
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.s(8)
                        text: I18n.t("quickactions.notepad.click_to_edit")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(10)
                        font.italic: true
                        color: root.alpha(root.cSubtext0, 0.75)
                        opacity: previewClickMa.containsMouse ? 1 : 0.55
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: previewClickMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: root.beginEditing()
                    }
                }

                // --- SOURCE EDITOR ---
                Item {
                    id: editorLayer
                    anchors.fill: parent
                    visible: root.isEditing
                    opacity: root.isEditing ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: root.s(14)
                        visible: editorArea.text.length === 0
                        text: I18n.t("quickactions.notepad.placeholder")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(13)
                        color: root.alpha(root.cSubtext0, 0.65)
                        z: 1
                    }

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: root.s(10)
                        contentWidth: width
                        contentHeight: Math.max(height, editorArea.paintedHeight + root.s(24))
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: editorArea
                            width: parent.width
                            color: root.cText
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(13)
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            selectionColor: root.alpha(root.cMauve, 0.35)
                            selectedTextColor: root.cText

                            onTextChanged: {
                                if (root.suppressSave) return;
                                root.updateActiveContent(text);
                            }

                            onActiveFocusChanged: {
                                if (!activeFocus && root.isEditing)
                                    root.finishEditing();
                            }

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape) {
                                    root.finishEditing();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
