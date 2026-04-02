import QtQuick 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

Item {
    id: root
    property alias onTap: button.onClicked
    property bool recording: applet.recording
    property int volume: applet.volumeLevel
    property int countdown: applet.recordingCountdown

    width: 48
    height: 48

    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    PlasmaComponents.IconButton {
        id: button
        anchors.top: parent.top
        anchors.topMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        iconName: recording ? "microphone-sensitivity-high" : (applet.voiceButtonVisible ? "microphone" : "keyboard")
        checked: recording
        checkable: true
        onClicked: applet.startSpeechToText()
        ToolTip {
            text: qsTr("Speech-to-text (CoPilot key, if present)")
        }
    }

    Text {
        id: statusText
        anchors.top: button.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: 10
        font.bold: true
        color: recording ? "#FF5A5A" : "#CCCCCC"
        text: {
            if (countdown > 0) return countdown.toString()
            if (recording) return "🎙️"
            return ""
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        width: parent.width * 0.7
        height: 4
        radius: 2
        color: recording ? "#FF5A5A" : "#888888"
        border.color: "#444444"
        border.width: 1

        Rectangle {
            id: bar
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * (volume / 100)
            height: parent.height
            color: recording ? "#00FF7F" : "#CCCCCC"
        }
    }

    PlasmaCore.DataSource {
        id: dummy
    }
}
