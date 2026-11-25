import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:epicollect/core/api.dart';

void main() {
  test('validation errors propagate without hiding server detail', () async {
    final api = Api(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode({
            'errors': {
              'answers': ['Required answer missing'],
            },
          }),
          422,
        ),
      ),
    );
    await expectLater(
      api.request('POST', '/projects/1/submissions', body: {'answers': []}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Required answer missing',
        ),
      ),
    );
  });
  test('submission uses bearer and stable idempotency key', () async {
    final api = Api(
      client: MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer test-token');
        expect(r.headers['Idempotency-Key'], 'stable-request-id');
        expect(jsonDecode(r.body)['answers'], isEmpty);
        return http.Response('{"data":{"id":1}}', 201);
      }),
    );
    api.token = 'test-token';
    expect(
      (await api.request(
        'POST',
        '/projects/1/submissions',
        body: {'answers': []},
        idempotencyKey: 'stable-request-id',
      ))['data']['id'],
      1,
    );
  });
}
