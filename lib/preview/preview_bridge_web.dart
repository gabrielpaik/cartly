import 'dart:convert';
import 'dart:html' as html;

typedef PreviewMessageHandler = void Function(Map<String, dynamic> data);

typedef PreviewReadyHandler = void Function();

void listenPreviewMessages(PreviewMessageHandler handler) {
  html.window.onMessage.listen((event) {
    final raw = event.data;
    Map<String, dynamic>? decoded;
    if (raw is String) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          decoded = Map<String, dynamic>.from(parsed as Map);
        }
      } catch (_) {}
    } else if (raw is Map) {
      decoded = Map<String, dynamic>.from(raw);
    }

    if (decoded == null) return;
    if (decoded['type'] != 'branding-preview') return;

    final payload = decoded['payload'];
    if (payload is Map) {
      handler(Map<String, dynamic>.from(payload));
    }
  });
}

void notifyPreviewReady() {
  html.window.parent?.postMessage(
    jsonEncode({'type': 'preview-ready'}),
    '*',
  );
}
