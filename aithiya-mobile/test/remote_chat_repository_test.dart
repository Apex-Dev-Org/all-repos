import 'dart:convert';

import 'package:aithiya_mobile/core/api/api_client.dart';
import 'package:aithiya_mobile/features/chat/data/remote_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('listSessions sends bearer token and maps threads', () async {
    final api = ApiClient(
      baseUrl: 'http://localhost:8000',
      apiPrefix: '/api/v1',
      getAccessToken: () async => 'token-123',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/threads');
        expect(request.url.queryParameters['limit'], '50');
        expect(
          request.headers['Authorization'] ?? request.headers['authorization'],
          'Bearer token-123',
        );
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'thread-1',
                'user_id': 'user-1',
                'title': 'Inheritance',
                'is_deleted': false,
                'created_at': '2026-05-16T10:30:00Z',
                'updated_at': '2026-05-16T10:31:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    final sessions = await RemoteChatRepository(api).listSessions();

    expect(sessions, hasLength(1));
    expect(sessions.first.id, 'thread-1');
    expect(sessions.first.title, 'Inheritance');
    expect(sessions.first.messages, isEmpty);
    api.close();
  });

  test(
    'getSession maps backend messages, citations, and attachments',
    () async {
      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        apiPrefix: '/api/v1',
        getAccessToken: () async => 'token-123',
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/threads') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'thread-1',
                  'user_id': 'user-1',
                  'title': 'Civil procedure',
                  'is_deleted': false,
                  'created_at': '2026-05-16T10:30:00Z',
                  'updated_at': '2026-05-16T10:31:05Z',
                },
              ]),
              200,
            );
          }

          if (request.url.path == '/api/v1/threads/thread-1/messages') {
            expect(request.url.queryParameters['limit'], '200');
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'message-user',
                    'thread_id': 'thread-1',
                    'user_id': 'user-1',
                    'role': 'user',
                    'content': 'Summarize this',
                    'sources': [
                      {
                        'filename': 'case.pdf',
                        'mime_type': 'application/pdf',
                        'size': 1024,
                      },
                    ],
                    'created_at': '2026-05-16T10:31:00Z',
                  },
                  {
                    'id': 'message-assistant',
                    'thread_id': 'thread-1',
                    'user_id': 'user-1',
                    'role': 'assistant',
                    'content': 'Under section 50...',
                    'sources': [
                      {
                        'doc_id': 'doc-1',
                        'title': 'Civil Procedure Code',
                        'similarity': 0.83,
                        'content_excerpt': 'Section 50 text',
                      },
                    ],
                    'created_at': '2026-05-16T10:31:05Z',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response('not found', 404);
        }),
      );

      final session = await RemoteChatRepository(api).getSession('thread-1');

      expect(session, isNotNull);
      expect(session!.messages, hasLength(2));
      expect(session.messages.first.attachments.single.name, 'case.pdf');
      expect(
        session.messages.last.citations.single,
        'Civil Procedure Code: Section 50 text',
      );
      api.close();
    },
  );

  test('sendMessage requires non-empty message text', () async {
    final api = ApiClient(
      baseUrl: 'http://localhost:8000',
      apiPrefix: '/api/v1',
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    );
    final repository = RemoteChatRepository(api);

    await expectLater(
      repository.sendMessage(
        sessionId: 'thread-1',
        text: '   ',
        languageCode: 'en',
      ),
      throwsA(isA<ChatBackendException>()),
    );
    api.close();
  });

  test('sendMessage can create a backend thread without thread_id', () async {
    var chatRequests = 0;
    final api = ApiClient(
      baseUrl: 'http://localhost:8000',
      apiPrefix: '/api/v1',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/chat') {
          chatRequests++;
          expect(request.method, 'POST');
          expect(request.body, contains('name="message"'));
          expect(request.body, isNot(contains('name="thread_id"')));
          return http.Response(
            jsonEncode({
              'thread_id': 'thread-new',
              'user_message_id': 'message-user',
              'assistant_message_id': 'message-assistant',
              'answer': 'This is the answer.',
              'sources': [],
            }),
            200,
          );
        }

        if (request.url.path == '/api/v1/threads') {
          return http.Response('[]', 200);
        }

        return http.Response('not found', 404);
      }),
    );

    final session = await RemoteChatRepository(api).sendMessage(
      sessionId: null,
      text: 'What does this say?',
      languageCode: 'en',
    );

    expect(chatRequests, 1);
    expect(session.id, 'thread-new');
    expect(session.messages, hasLength(2));
    expect(session.messages.first.content, 'What does this say?');
    expect(session.messages.last.content, 'This is the answer.');
    api.close();
  });
}
