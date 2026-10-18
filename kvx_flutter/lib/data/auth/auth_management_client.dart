import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/auth/account_authentication.dart';
import '../../domain/auth/session.dart';

class AuthManagementClient implements AccountAuthRepository {
  static final Uri _origin = Uri.parse('https://khuonvien.vn');
  static const _limit = 16 * 1024;
  final SessionAccess authority;
  final int generation;
  final http.Client client;
  Completer<AccountAuthFailureKind>? _abort;
  int _revision = 0;

  AuthManagementClient({
    required this.authority,
    required this.generation,
    required this.client,
  });

  @override
  void cancel() {
    _revision++;
    final abort = _abort;
    _abort = null;
    if (abort != null && !abort.isCompleted) {
      abort.complete(AccountAuthFailureKind.cancelled);
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, String>? body,
    bool Function()? beginDispatch,
    MutationLease? lease,
  ]) async {
    final revision = ++_revision;
    final snapshot = authority.snapshot(expectedGeneration: generation);
    final elapsed = Stopwatch()..start();
    final abort = Completer<AccountAuthFailureKind>();
    _abort = abort;
    final request =
        http.AbortableRequest(
            method,
            _origin.resolve(path),
            abortTrigger: abort.future,
          )
          ..followRedirects = false
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer ${snapshot.token}';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final streamed =
          await Future.any<http.StreamedResponse>([
            (lease == null
                ? authority.dispatch(snapshot.generation, () {
                    if (beginDispatch != null && !beginDispatch()) {
                      throw const AccountAuthFailure(
                        AccountAuthFailureKind.cancelled,
                      );
                    }
                    return client.send(request);
                  })
                : (authority as ReconciliationAccess).dispatchPrepared(
                    lease,
                    () {
                      if (beginDispatch != null && !beginDispatch()) {
                        throw const AccountAuthFailure(
                          AccountAuthFailureKind.cancelled,
                        );
                      }
                      return client.send(request);
                    },
                  )),
            abort.future.then((reason) => throw AccountAuthFailure(reason)),
          ]).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              if (!abort.isCompleted) {
                abort.complete(AccountAuthFailureKind.network);
              }
              throw TimeoutException('auth-management timeout');
            },
          );
      if (revision != _revision || !authority.isCurrent(snapshot.generation)) {
        throw const AccountAuthFailure(AccountAuthFailureKind.stale);
      }
      final remaining = const Duration(seconds: 20) - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        if (!abort.isCompleted) abort.complete(AccountAuthFailureKind.network);
        throw const AccountAuthFailure(AccountAuthFailureKind.network);
      }
      final bytes = await _boundedBody(streamed.stream, abort, remaining);
      if (revision != _revision || !authority.isCurrent(snapshot.generation)) {
        throw const AccountAuthFailure(AccountAuthFailureKind.stale);
      }
      final contentType = streamed.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (contentType != 'application/json') {
        throw const AccountAuthFailure(
          AccountAuthFailureKind.malformedResponse,
        );
      }
      final dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes));
      } catch (_) {
        throw const AccountAuthFailure(
          AccountAuthFailureKind.malformedResponse,
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const AccountAuthFailure(
          AccountAuthFailureKind.malformedResponse,
        );
      }
      if (streamed.statusCode == 401 &&
          decoded['status'] == 'error' &&
          decoded['code'] == 'authentication_required') {
        if (revision != _revision ||
            !authority.isCurrent(snapshot.generation)) {
          throw const AccountAuthFailure(AccountAuthFailureKind.stale);
        }
        if (!await authority.unauthorized(snapshot.generation)) {
          throw const AccountAuthFailure(AccountAuthFailureKind.stale);
        }
        throw const AccountAuthFailure(
          AccountAuthFailureKind.authenticationRequired,
        );
      }
      if (streamed.statusCode == 200 && decoded['status'] == 'success') {
        return decoded;
      }
      if (decoded['status'] != 'error' || decoded['code'] is! String) {
        throw const AccountAuthFailure(
          AccountAuthFailureKind.malformedResponse,
        );
      }
      throw AccountAuthFailure(
        _failure(streamed.statusCode, decoded['code'] as String),
      );
    } on AccountAuthFailure {
      rethrow;
    } catch (_) {
      if (revision != _revision || !authority.isCurrent(snapshot.generation)) {
        throw const AccountAuthFailure(AccountAuthFailureKind.stale);
      }
      throw const AccountAuthFailure(AccountAuthFailureKind.network);
    } finally {
      if (identical(_abort, abort)) _abort = null;
      if (!abort.isCompleted) {
        abort.complete(AccountAuthFailureKind.cancelled);
      }
    }
  }

  static Future<List<int>> _boundedBody(
    Stream<List<int>> stream,
    Completer<AccountAuthFailureKind> abort,
    Duration remaining,
  ) async {
    final done = Completer<List<int>>();
    final bytes = <int>[];
    late final StreamSubscription<List<int>> subscription;
    final timer = Timer(remaining, () {
      if (!abort.isCompleted) {
        abort.complete(AccountAuthFailureKind.network);
      }
      if (!done.isCompleted) {
        done.completeError(
          const AccountAuthFailure(AccountAuthFailureKind.network),
        );
      }
    });
    subscription = stream.listen(
      (chunk) {
        if (done.isCompleted) return;
        if (chunk.length > _limit - bytes.length) {
          if (!abort.isCompleted) {
            abort.complete(AccountAuthFailureKind.malformedResponse);
          }
          done.completeError(
            const AccountAuthFailure(AccountAuthFailureKind.malformedResponse),
          );
          unawaited(subscription.cancel());
        } else {
          bytes.addAll(chunk);
        }
      },
      onError: (Object _) {
        if (!done.isCompleted) {
          done.completeError(
            const AccountAuthFailure(AccountAuthFailureKind.network),
          );
        }
      },
      onDone: () {
        if (!done.isCompleted) done.complete(bytes);
      },
      cancelOnError: true,
    );
    unawaited(
      abort.future.then((reason) async {
        if (!done.isCompleted) done.completeError(AccountAuthFailure(reason));
        await subscription.cancel();
      }),
    );
    try {
      return await done.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  static AccountAuthFailureKind _failure(int status, String code) => switch ((
    status,
    code,
  )) {
    (401, 'invalid_provider_credential') =>
      AccountAuthFailureKind.invalidProviderCredential,
    (400, 'malformed_request') => AccountAuthFailureKind.malformedRequest,
    (403, 'reauthentication_failed') =>
      AccountAuthFailureKind.reauthenticationFailed,
    (403, 'reauthentication_required') =>
      AccountAuthFailureKind.reauthenticationRequired,
    (409, 'last_authentication_method') =>
      AccountAuthFailureKind.lastAuthenticationMethod,
    (422, 'unsupported_method') => AccountAuthFailureKind.unsupportedMethod,
    (422, 'unsupported_provider') => AccountAuthFailureKind.unsupportedProvider,
    (429, 'rate_limited') => AccountAuthFailureKind.rateLimited,
    (503, 'provider_unavailable') => AccountAuthFailureKind.providerUnavailable,
    (500, 'internal_error') => AccountAuthFailureKind.serverFailure,
    _ => AccountAuthFailureKind.unknown,
  };

  static AccountAuthFailure malformed() =>
      const AccountAuthFailure(AccountAuthFailureKind.malformedResponse);

  @override
  Future<AuthenticationMethods> methods() async {
    final json = await _send('GET', '/api/auth/methods');
    final password = json['password'];
    final recovery = json['recovery'];
    final providers = json['providers'];
    if (password is! Map ||
        password['usable'] is! bool ||
        recovery is! Map ||
        recovery['codes_enrolled'] is! bool ||
        providers is! List) {
      throw malformed();
    }
    final methods = <ProviderMethod>[];
    for (final entry in providers) {
      if (entry is! Map ||
          entry['provider'] is! String ||
          entry['usable'] is! bool ||
          entry['can_unlink'] is! bool) {
        throw malformed();
      }
      final provider = entry['provider'] as String;
      if (!RegExp(r'^[a-z_]{1,32}$').hasMatch(provider)) {
        throw malformed();
      }
      methods.add(
        ProviderMethod(
          provider,
          entry['usable'] as bool,
          entry['can_unlink'] as bool,
        ),
      );
    }
    if (methods.map((method) => method.provider).toSet().length !=
        methods.length) {
      throw malformed();
    }
    return AuthenticationMethods(
      password['usable'] as bool,
      List.unmodifiable(methods),
      recovery['codes_enrolled'] as bool,
    );
  }

  @override
  Future<ReauthenticationGrant> reauthenticate(
    String password,
    ReauthenticationPurpose purpose,
  ) async {
    final json = await _send('POST', '/api/auth/reauthentications', {
      'purpose': purpose.wire,
      'method': 'password',
      'password': password,
    });
    final token = json['reauthentication_token'];
    final expiry = json['expires_at'];
    final parsed = expiry is String ? DateTime.tryParse(expiry) : null;
    if (token is! String || token.isEmpty || parsed == null) {
      throw malformed();
    }
    return ReauthenticationGrant(token, parsed, purpose);
  }

  @override
  Future<List<String>> rotateCodes(
    ReauthenticationGrant grant, {
    required MutationLease lease,
    required bool Function() beginDispatch,
  }) async {
    final token = grant.consumeFor(
      ReauthenticationPurpose.rotateRecoveryCodes,
      DateTime.now(),
    );
    if (token == null) {
      throw const AccountAuthFailure(
        AccountAuthFailureKind.reauthenticationRequired,
      );
    }
    final json = await _send(
      'POST',
      '/api/auth/recovery_codes',
      {'reauthentication_token': token},
      beginDispatch,
      lease,
    );
    final codes = json['codes'];
    if (json['code'] != 'recovery_codes_rotated' ||
        codes is! List ||
        codes.length != 10 ||
        codes.any((code) => code is! String || code.isEmpty)) {
      throw malformed();
    }
    return List<String>.unmodifiable(codes.cast<String>());
  }

  @override
  Future<void> unlinkGoogle(
    ReauthenticationGrant grant, {
    required MutationLease lease,
    required bool Function() beginDispatch,
  }) async {
    final token = grant.consumeFor(
      ReauthenticationPurpose.unlinkIdentity,
      DateTime.now(),
    );
    if (token == null) {
      throw const AccountAuthFailure(
        AccountAuthFailureKind.reauthenticationRequired,
      );
    }
    final json = await _send(
      'DELETE',
      '/api/auth/social_identities/google',
      {'reauthentication_token': token},
      beginDispatch,
      lease,
    );
    if (json['code'] != 'unlinked' && json['code'] != 'not_linked') {
      throw malformed();
    }
  }
}
