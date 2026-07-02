import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets

CCCard {
    id: notifListCard
    cardDelay: 240
    Layout.fillWidth: true
    Layout.preferredHeight: (shellRoot && shellRoot.notifList.count > 0) ? Math.min(250, 48 + notifListView.contentHeight) : 100
    Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Notifications"
                color: shellRoot ? shellRoot.colFg : "#ffffff"
                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 12; bold: true }
            }
            Rectangle {
                visible: shellRoot && shellRoot.notifList.count > 0
                Layout.preferredHeight: 18
                Layout.preferredWidth: 24
                radius: 9
                color: shellRoot ? shellRoot.colHover : Qt.rgba(1, 1, 1, 0.1)
                Text {
                    anchors.centerIn: parent
                    text: shellRoot ? shellRoot.notifList.count : 0
                    color: shellRoot ? shellRoot.colFg : "#ffffff"
                    font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 9; bold: true }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: shellRoot && shellRoot.notifList.count > 0
                text: "Clear All"
                color: clearAllMouse.containsMouse ? (shellRoot ? shellRoot.colFg : "#ffffff") : (shellRoot ? shellRoot.colMuted : "#888888")
                font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 10; bold: true }
                MouseArea {
                    id: clearAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (shellRoot) {
                            for (var i = shellRoot.notifList.count - 1; i >= 0; i--) {
                                var n = shellRoot.notifList.get(i).notifObj;
                                if (n) {
                                    try {
                                        if (typeof n.dismiss === "function") n.dismiss();
                                        else if (typeof n.close === "function") n.close();
                                    } catch(e) {}
                                }
                            }
                            shellRoot.notifList.clear();
                        }
                    }
                }
            }
        }

        ListView {
            id: notifListView
            visible: shellRoot && shellRoot.notifList.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: shellRoot ? shellRoot.notifList : null
            spacing: 6
            delegate: Rectangle {
                 id: delegateRoot
                 width: notifListView.width
                 clip: true
                 property bool isExpanded: false
                 property bool hasActions: notifObj && notifObj.actions && notifObj.actions.length > 0
                 property int notifIndex: index
                 height: isExpanded ? Math.max(58, 36 + bodyText.implicitHeight + (hasActions ? 32 : 0)) : 58
                 radius: 12
                 color: Qt.rgba(1, 1, 1, 0.04)
                 border.color: Qt.rgba(1, 1, 1, 0.08)
                 border.width: 1

                 Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                 MouseArea {
                     anchors.fill: parent
                     hoverEnabled: true
                     onClicked: delegateRoot.isExpanded = !delegateRoot.isExpanded
                 }

                 RowLayout {
                     anchors.fill: parent
                     anchors.margins: 8
                     spacing: 8

                     Rectangle {
                         width: 32
                         height: 32
                         radius: 8
                         color: Qt.rgba(1, 1, 1, 0.05)
                         clip: true
                         IconImage {
                             id: itemIconImg
                             anchors.fill: parent
                             source: appIcon
                             visible: appIcon !== ""
                         }
                         Text {
                             anchors.centerIn: parent
                             text: "󰂚"
                             color: shellRoot ? shellRoot.colFg : "#ffffff"
                             font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 14 }
                             visible: !itemIconImg.visible
                         }
                     }

                     ColumnLayout {
                         Layout.fillWidth: true
                         spacing: 1
                         Text {
                             text: (summary && !delegateRoot.isExpanded) ? summary.replace(/\n/g, " ") : (summary || "")
                             color: shellRoot ? shellRoot.colFg : "#ffffff"
                             font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 11; bold: true }
                             elide: Text.ElideRight
                             Layout.fillWidth: true
                         }
                         Text {
                             id: bodyText
                             text: (body && !delegateRoot.isExpanded) ? body.replace(/\n/g, " ") : (body || "")
                             color: shellRoot ? Qt.rgba(shellRoot.colFg.r, shellRoot.colFg.g, shellRoot.colFg.b, 0.65) : Qt.rgba(1, 1, 1, 0.65)
                             font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 9 }
                             elide: delegateRoot.isExpanded ? Text.ElideNone : Text.ElideRight
                             wrapMode: delegateRoot.isExpanded ? Text.Wrap : Text.NoWrap
                             Layout.fillWidth: true
                         }

                         RowLayout {
                             visible: delegateRoot.isExpanded && delegateRoot.hasActions
                             spacing: 8
                             Layout.fillWidth: true
                             Layout.topMargin: 4

                             Repeater {
                                 model: notifObj ? notifObj.actions : null
                                 delegate: MouseArea {
                                     id: actionBtn
                                     implicitWidth: actionLbl.implicitWidth + 16
                                     implicitHeight: 20
                                     hoverEnabled: true

                                     Rectangle {
                                         anchors.fill: parent
                                         radius: 6
                                         color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                         border.color: "transparent"
                                     }

                                     Text {
                                         id: actionLbl
                                         anchors.centerIn: parent
                                         text: modelData.text
                                         color: shellRoot ? shellRoot.colFg : "white"
                                         font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 9; bold: true }
                                     }

                                     onClicked: {
                                         if (notifObj) {
                                             notifObj.invokeAction(modelData.identifier);
                                         }
                                         if (shellRoot) {
                                             shellRoot.notifList.remove(notifIndex);
                                         }
                                     }
                                 }
                             }
                         }
                     }

                     MouseArea {
                         width: 24
                         height: 24
                         hoverEnabled: true
                         onClicked: {
                             var n = notifObj;
                             if (n) {
                                 try {
                                     if (typeof n.dismiss === "function") n.dismiss();
                                     else if (typeof n.close === "function") n.close();
                                 } catch(e) {
                                     console.warn("NotificationList: dismiss failed:", e);
                                 }
                             }
                             if (shellRoot) shellRoot.notifList.remove(index);
                         }
                         Text {
                             anchors.centerIn: parent
                             text: "󰅖"
                             color: parent.containsMouse ? (shellRoot ? shellRoot.colCrit : "#ff0000") : (shellRoot ? shellRoot.colMuted : "#888888")
                             font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 14 }
                         }
                     }
                 }
             }
        }

        Item {
            visible: !(shellRoot && shellRoot.notifList.count > 0)
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                width: parent.width

                Text {
                    text: "󰂛"
                    color: shellRoot ? shellRoot.colMuted : "#888888"
                    font { family: shellRoot ? shellRoot.iconFontFamily : "sans-serif"; pixelSize: 26 }
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.6
                }

                Text {
                    text: "All Caught Up"
                    color: shellRoot ? shellRoot.colFg : "#ffffff"
                    font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 10; bold: true }
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "No new notifications"
                    color: shellRoot ? shellRoot.colMuted : "#888888"
                    font { family: shellRoot ? shellRoot.fontFamily : "sans-serif"; pixelSize: 9 }
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
