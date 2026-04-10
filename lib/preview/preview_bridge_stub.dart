typedef PreviewMessageHandler = void Function(Map<String, dynamic> data);

typedef PreviewReadyHandler = void Function();

void listenPreviewMessages(PreviewMessageHandler handler) {}

void notifyPreviewReady() {}
