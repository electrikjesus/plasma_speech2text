#include <QAction>
#include <QDebug>
#include <QFile>
#include <QGuiApplication>
#include <QInputMethod>
#include <QRandomGenerator>
#include <QInputMethodEvent>
#include <QKeySequence>
#include <QProcess>
#include <QSize>
#include <QTimer>
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
#include <QInputDevice>
#endif
#include <KConfigGroup>
#include <KGlobalAccel>
#include <KLocalizedString>
#include <KPluginFactory>
#include <KPluginMetaData>
#include <KSharedConfig>
#include <Plasma/Applet>

class SpeechToTextApplet : public Plasma::Applet
{
    Q_OBJECT
    Q_PROPERTY(bool voiceButtonVisible READ voiceButtonVisible NOTIFY voiceButtonVisibleChanged)
    Q_PROPERTY(bool inputFieldFocused READ inputFieldFocused NOTIFY inputFieldFocusedChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(int volumeLevel READ volumeLevel NOTIFY volumeLevelChanged)
    Q_PROPERTY(int recordingCountdown READ recordingCountdown NOTIFY recordingCountdownChanged)

public:
    SpeechToTextApplet(QObject *parent, const QVariantList &args)
        : Plasma::Applet(parent, KPluginMetaData(), args)
    {
        setHasConfigurationInterface(false);

        loadSettings();

        m_globalAction = new QAction(i18n("Start Speech-to-Text"), this);
        connect(m_globalAction, &QAction::triggered,
                this, &SpeechToTextApplet::startSpeechToText);

        connect(&m_countdownTimer, &QTimer::timeout,
                this, &SpeechToTextApplet::onCountdownTick);

        const QList<QKeySequence> defaultShortcut = {QKeySequence(Qt::META + Qt::Key_S)};
        KGlobalAccel::self()->setShortcut(m_globalAction, defaultShortcut, KGlobalAccel::NoAutoloading);

        connect(qApp->inputMethod(), &QInputMethod::visibleChanged,
                this, &SpeechToTextApplet::onInputMethodVisibleChanged);
        connect(qApp, &QGuiApplication::focusObjectChanged,
                this, &SpeechToTextApplet::onFocusObjectChanged);
        initVolumeTimer();        QTimer::singleShot(0, this, &SpeechToTextApplet::checkAttachedKeyboards);
        updateVoiceButtonVisibility();
    }

    bool voiceButtonVisible() const
    {
        // For testing and always-available behavior, keep always visible.
        // In production, tie to input method + attached keyboard + focus state.
        return true;
    }

    bool inputFieldFocused() const
    {
        return m_inputFieldFocused;
    }

    bool recording() const
    {
        return m_recording;
    }

    int volumeLevel() const
    {
        return m_volumeLevel;
    }

    int recordingCountdown() const
    {
        return m_recordingCountdown;
    }

    Q_INVOKABLE void startSpeechToText()
    {
        qDebug() << "Speech-to-text trigger event received.";
        m_countdownRemaining = 3;
        setRecordingCountdown(3);
        m_countdownTimer.start(1000);
    }

    void doSpeechToText()
    {
        setRecording(true);

        // Start volume animation while STT processes
        m_volumeTimer.start(50);

        QString recognizedText;
        if (!m_sttCommand.isEmpty()) {
            QProcess proc;
            // Run the helper script which handles audio capture + Vosk transcription
            // The helper script will manage arecord, sox RMS, and vosk-transcriber
            proc.start(m_sttCommand, QStringList());
            
            if (!proc.waitForFinished(90 * 1000)) {  // 90 second timeout for transcription
                qWarning() << "STT command timed out or failed:" << m_sttCommand;
                recognizedText = tr("[Transcription timed out]");
            } else {
                recognizedText = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
                if (recognizedText.isEmpty()) {
                    qWarning() << "STT command returned empty output.";
                    recognizedText = tr("[No speech detected]");
                }
            }
        }

        if (recognizedText.isEmpty() || recognizedText.contains("not configured")) {
            recognizedText = tr("[Speech-to-text not configured - check EngineCommand in ~/.config/s2tconfig]");
        }

        commitRecognizedText(recognizedText);
        stopRecording();
    }

    void stopRecording()
    {
        m_volumeTimer.stop();
        setVolumeLevel(0);
        setRecording(false);
    }

    void setRecording(bool recording)
    {
        if (m_recording == recording)
            return;
        m_recording = recording;
        emit recordingChanged();
    }

    void setVolumeLevel(int value)
    {
        const int v = qBound(0, value, 100);
        if (m_volumeLevel == v)
            return;
        m_volumeLevel = v;
        emit volumeLevelChanged();
    }

    void setRecordingCountdown(int value)
    {
        if (m_recordingCountdown == value)
            return;
        m_recordingCountdown = value;
        emit recordingCountdownChanged();
    }

    void init() override
    {
        // initial size is handled by QML layout; no direct API in KF5 Applet.
    }

signals:
    void voiceButtonVisibleChanged();
    void inputFieldFocusedChanged();
    void recordingChanged();
    void volumeLevelChanged();
    void recordingCountdownChanged();

private slots:
    void onInputMethodVisibleChanged()
    {
        m_inputModeActive = qApp->inputMethod()->isVisible();
        updateVoiceButtonVisibility();
    }

    void onFocusObjectChanged(QObject *focus)
    {
        m_inputFieldFocused = (focus && focus->inherits("QQuickItem"));
        emit inputFieldFocusedChanged();
        updateVoiceButtonVisibility();
    }

    void onCountdownTick()
    {
        m_countdownRemaining--;
        if (m_countdownRemaining <= 0) {
            m_countdownTimer.stop();
            setRecordingCountdown(0);
            doSpeechToText();
        } else {
            setRecordingCountdown(m_countdownRemaining);
        }
    }

    void checkAttachedKeyboards()
    {
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
        for (const QInputDevice *device : QInputDevice::devices()) {
            if (device->type() != QInputDevice::DeviceType::Keyboard)
                continue;
            const QString lowerName = device->name().toLower();
            if (lowerName.contains("copilot") || lowerName.contains("ai")) {
                m_hasCopilotKeyboard = true;
                break;
            }
        }
#else
        m_hasCopilotKeyboard = detectCopilotKeyboardQt5();
        qDebug() << "Qt5 CoPilot keyboard heuristic:" << m_hasCopilotKeyboard;
#endif
        updateVoiceButtonVisibility();
    }

private:
    void loadSettings()
    {
        auto config = KSharedConfig::openConfig(QStringLiteral("s2tconfig"));
        KConfigGroup group(config, "SpeechToText");
        m_sttCommand = group.readEntry("EngineCommand", QString());
        qDebug() << "Loaded STT command:" << m_sttCommand;
    }

    void initVolumeTimer()
    {
        m_volumeTimer.setInterval(50);
        connect(&m_volumeTimer, &QTimer::timeout, this, [this]() {
            // simulated mic volume while recording
            if (m_recording) {
                int randomLevel = QRandomGenerator::global()->bounded(20, 71);
                setVolumeLevel(randomLevel);
            }
        });
    }

    bool detectCopilotKeyboardQt5() const
    {
        QFile devices("/proc/bus/input/devices");
        if (!devices.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qWarning() << "Cannot open /proc/bus/input/devices";
            return false;
        }
        const QString content = QString::fromUtf8(devices.readAll()).toLower();
        return content.contains("copilot") || content.contains("ai");
    }

    void commitRecognizedText(const QString &text)
    {
        QObject *focusObj = qApp->focusObject();
        if (!focusObj) {
            qWarning() << "No focused widget to commit text.";
            return;
        }

        QInputMethodEvent event(text, QList<QInputMethodEvent::Attribute>());
        QCoreApplication::sendEvent(focusObj, &event);
        qDebug() << "Committed text to focused object:" << text;
    }

    void updateVoiceButtonVisibility()
    {
        emit voiceButtonVisibleChanged();
    }

    bool m_inputModeActive = false;
    bool m_hasCopilotKeyboard = false;
    bool m_inputFieldFocused = false;
    bool m_recording = false;
    int m_volumeLevel = 0;
    int m_recordingCountdown = 0;
    int m_countdownRemaining = 0;
    QString m_sttCommand;
    QAction *m_globalAction = nullptr;
    QTimer m_volumeTimer;
    QTimer m_countdownTimer;
};

K_PLUGIN_CLASS_WITH_JSON(SpeechToTextApplet, "metadata.json")

#include "s2t.moc"
