// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> requestWebNotificationPermission() async {
  try {
    if (html.Notification.supported) {
      if (html.Notification.permission != 'granted') {
        await html.Notification.requestPermission();
      }
    }
  } catch (_) {}
}

void showWebNotification(String title, String body) {
  try {
    if (html.Notification.supported && html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  } catch (_) {}
}
