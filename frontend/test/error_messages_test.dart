import 'package:bambootrace/services/api_service.dart';
import 'package:bambootrace/utils/error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows structured API validation message', () {
    final error = ApiException(
      'Price must be greater than or equal to 0',
      statusCode: 422,
    );

    expect(
      friendlyErrorMessage(error),
      'Price must be greater than or equal to 0',
    );
  });

  test('hides invalid response implementation details', () {
    final error = ApiException(
      'The server returned an invalid response. Please try again later.',
      statusCode: 502,
    );

    expect(
      friendlyErrorMessage(error),
      'The server returned an invalid response. Please try again later.',
    );
  });
}
