import '../services/api_service.dart';

String friendlyErrorMessage(Object? error) {
  if (error == null) return 'Something went wrong. Please try again.';
  if (error is ProfileRequiredException) return error.message;
  if (error is ApiConfigurationException) return error.message;
  if (error is ApiException) return error.message;

  final message = error.toString().replaceFirst('Exception: ', '').trim();
  if (message.isEmpty) return 'Something went wrong. Please try again.';

  final lowerMessage = message.toLowerCase();
  if (lowerMessage.contains('clientexception') ||
      lowerMessage.contains('socketexception') ||
      lowerMessage.contains('failed host lookup') ||
      lowerMessage.contains('connection refused') ||
      lowerMessage.contains('xmlhttprequest error')) {
    return 'Unable to reach the server. Check your connection and API URL.';
  }

  if (lowerMessage.contains('request failed with status 500')) {
    return 'The server had a problem. Please try again later.';
  }

  return message;
}

