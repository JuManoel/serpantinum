//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "NoteCard.qml"
import "../../singletons"
import "../../"
import "../../reusables"

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property bool isEditing: NotesManager.editingNoteId !== ""
    property string iconFont: "Font Awesome 6 Free Solid"
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    readonly property bool keepAlive: root.isEditing

    property var interceptedShortcuts: {
        if (!root.isEditing) return [];
        return ["Return", "Enter", "Left", "Right", "Up", "Down", "Tab", "Shift+Tab", "Backspace"];
    }

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

    property color cMantle: ThemeBackend.mantle
    property color cText: ThemeBackend.text
    property color cSubtext0: ThemeBackend.subtext0

    function finishAllEditing() {
        NotesManager.editingNoteId = "";
        if (typeof expandedNoteCard !== "undefined" && expandedNoteCard.visible)
            expandedNoteCard.finishEditing();
        for (let i = 0; i < notesList.contentItem.children.length; i++) {
            let child = notesList.contentItem.children[i];
            if (child && typeof child.finishEditing === "function")
                child.finishEditing();
        }
    }

    function createNote() {
        NotesManager.createNote();
    }

    function deleteActiveNote() {
        if (NotesManager.activeId !== "")
            NotesManager.deleteNoteById(NotesManager.activeId);
    }

    function resetNotesListScroll() {
        notesList.contentY = 0;
        notesList.returnToBounds();
    }

    onIsActiveTabChanged: {
        if (!isActiveTab && isEditing) root.finishAllEditing();
    }

    Component.onDestruction: NotesManager.persistNotes()

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
                    enabled: NotesManager.activeId !== ""
                    onTriggered: root.deleteActiveNote()
                }
            }

            Item {
                id: notesHost
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                readonly property var expandedNote: {
                    let id = NotesManager.expandedId;
                    if (!id) return null;
                    return NotesManager.getNoteById(id);
                }

                ListView {
                    id: notesList
                    anchors.fill: parent
                    spacing: root.s(4)
                    model: NotesManager.notesModel
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: NotesManager.expandedId === ""
                    reuseItems: true

                    Connections {
                        target: NotesManager.notesModel
                        function onCountChanged() {
                            Qt.callLater(root.resetNotesListScroll);
                        }
                    }

                    Connections {
                        target: NotesManager
                        function onExpandedIdChanged() {
                            if (NotesManager.expandedId === "")
                                Qt.callLater(root.resetNotesListScroll);
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: NotesManager.notesModel.count === 0
                        text: I18n.t("quickactions.notepad.empty_list")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(11)
                        color: root.cSubtext0
                        horizontalAlignment: Text.AlignHCenter
                    }

                    delegate: NoteCard {
                        noteId: model.id
                        noteContent: model.content
                        noteUpdatedAt: model.updatedAt
                        index: index
                        isSelected: model.id === NotesManager.activeId
                        isExpanded: false
                        scaleFunc: function(v) { return root.s(v); }
                        listView: notesList

                        onDismissRequested: () => {
                            NotesManager.deleteNoteById(model.id);
                            root.resetNotesListScroll();
                        }
                    }
                }

                NoteCard {
                    id: expandedNoteCard
                    anchors.fill: parent
                    visible: NotesManager.expandedId !== ""
                    noteId: NotesManager.expandedId
                    noteContent: notesHost.expandedNote ? notesHost.expandedNote.content : ""
                    noteUpdatedAt: notesHost.expandedNote ? notesHost.expandedNote.updatedAt : 0
                    index: NotesManager.indexOfId(NotesManager.expandedId)
                    isSelected: true
                    isExpanded: true
                    availableExpandHeight: notesHost.height
                    scaleFunc: function(v) { return root.s(v); }

                    onDismissRequested: () => {
                        NotesManager.deleteNoteById(NotesManager.expandedId);
                        root.resetNotesListScroll();
                    }
                }
            }
        }
    }
}
