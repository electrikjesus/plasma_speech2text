// vosk-stt.h - Header for Vosk STT integration
#ifndef VOSK_STT_H
#define VOSK_STT_H

#include <QString>
#include <QObject>

class VoskSTT : public QObject
{
    Q_OBJECT

public:
    explicit VoskSTT(QObject *parent = nullptr);
    ~VoskSTT();

    bool initialize(const QString &modelPath);
    QString transcribeAudio(const QByteArray &audioData);

private:
    class Private;
    Private *d;
};

#endif // VOSK_STT_H