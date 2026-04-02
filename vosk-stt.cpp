// vosk-stt.cpp - Implementation for Vosk STT integration
#include "vosk-stt.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>

// Note: This requires Vosk C++ library
// Build instructions:
// 1. Clone Vosk: git clone https://github.com/alphacep/vosk-api
// 2. Build: cd vosk-api/src && make
// 3. Install headers and libs to system or project

#ifdef USE_VOSK
#include <vosk_api.h>  // Vosk C API
#endif

class VoskSTT::Private
{
public:
#ifdef USE_VOSK
    VoskModel *model = nullptr;
    VoskRecognizer *recognizer = nullptr;
#endif
    bool initialized = false;
};

VoskSTT::VoskSTT(QObject *parent)
    : QObject(parent)
    , d(new Private)
{
}

VoskSTT::~VoskSTT()
{
#ifdef USE_VOSK
    if (d->recognizer) {
        vosk_recognizer_free(d->recognizer);
    }
    if (d->model) {
        vosk_model_free(d->model);
    }
#endif
    delete d;
}

bool VoskSTT::initialize(const QString &modelPath)
{
#ifdef USE_VOSK
    d->model = vosk_model_new(modelPath.toUtf8().constData());
    if (!d->model) {
        qWarning() << "Failed to load Vosk model from:" << modelPath;
        return false;
    }

    d->recognizer = vosk_recognizer_new(d->model, 16000.0f);
    if (!d->recognizer) {
        qWarning() << "Failed to create Vosk recognizer";
        vosk_model_free(d->model);
        d->model = nullptr;
        return false;
    }

    d->initialized = true;
    qDebug() << "Vosk STT initialized successfully";
    return true;
#else
    qWarning() << "Vosk support not compiled in. Define USE_VOSK and link vosk library.";
    return false;
#endif
}

QString VoskSTT::transcribeAudio(const QByteArray &audioData)
{
    if (!d->initialized) {
        qWarning() << "Vosk STT not initialized";
        return QString();
    }

#ifdef USE_VOSK
    if (vosk_recognizer_accept_waveform(d->recognizer, audioData.constData(), audioData.size())) {
        const char *result = vosk_recognizer_result(d->recognizer);
        QJsonDocument doc = QJsonDocument::fromJson(result);
        QJsonObject obj = doc.object();
        return obj.value("text").toString();
    } else {
        // Partial result
        const char *partial = vosk_recognizer_partial_result(d->recognizer);
        QJsonDocument doc = QJsonDocument::fromJson(partial);
        QJsonObject obj = doc.object();
        return obj.value("partial").toString();
    }
#else
    return QStringLiteral("Vosk not available - placeholder transcription");
#endif
}

// Integration into s2t.cpp:
//
// In SpeechToTextApplet constructor:
//     m_vosk = new VoskSTT(this);
//     QString modelPath = QStandardPaths::locate(QStandardPaths::AppDataLocation,
//                                                "vosk-model-small-en-us-0.15");
//     if (!modelPath.isEmpty()) {
//         m_vosk->initialize(modelPath);
//     }
//
// In startSpeechToText():
//     // Record audio to QByteArray audioData...
//     QString text = m_vosk->transcribeAudio(audioData);
//     commitRecognizedText(text);