import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('account deletion is server-authorized and scoped to the caller', () {
    final edgeFunction = read('supabase/functions/delete-account/index.ts');
    expect(edgeFunction, contains("caller.auth.getUser(token)"));
    expect(edgeFunction, isNot(contains('request.json')));
    expect(edgeFunction, contains("admin.auth.admin.deleteUser(user.id)"));
    expect(edgeFunction, contains("listOwnedObjects(admin, bucket, user.id)"));
  });

  test('storage cleanup happens before auth deletion', () {
    final edgeFunction = read('supabase/functions/delete-account/index.ts');
    expect(
      edgeFunction.indexOf("admin.storage.from(bucket).remove"),
      lessThan(edgeFunction.indexOf("admin.auth.admin.deleteUser(user.id)")),
    );
  });

  test('shared-record notifications are removed before their source rows cascade',
      () {
    final edgeFunction = read('supabase/functions/delete-account/index.ts');
    expect(edgeFunction, contains('deleteSharedRecordNotifications'));
    expect(edgeFunction, contains("deleteBySource('interest_requests'"));
    expect(edgeFunction, contains("deleteBySource('matches'"));
    expect(edgeFunction, contains("'chat_messages'"));
    expect(
      edgeFunction.indexOf('await deleteSharedRecordNotifications(admin, user.id)'),
      lessThan(edgeFunction.indexOf('admin.auth.admin.deleteUser(user.id)')),
    );
  });

  test('browser CORS is restricted to the Fusion Ventures deletion page', () {
    final edgeFunction = read('supabase/functions/delete-account/index.ts');
    expect(edgeFunction, contains("'https://www.fusionventuresglobal.com'"));
    expect(edgeFunction, contains("'https://fusionventuresglobal.com'"));
    expect(edgeFunction, contains("'Access-Control-Allow-Origin': origin"));
    expect(edgeFunction, isNot(contains("'Access-Control-Allow-Origin': '*'")));
    expect(edgeFunction, contains("if (request.method === 'OPTIONS')"));
  });

  test('Flutter requires deliberate confirmation and signs out after success',
      () {
    final screen = read('lib/features/auth/delete_account_screen.dart');
    final repository = read('lib/features/supabase_backend/kaam_backend.dart');
    expect(screen, contains("_confirmation.text.trim() != 'DELETE'"));
    expect(repository, contains("client.functions.invoke('delete-account')"));
    expect(repository, contains('auth.signOut(scope: SignOutScope.global)'));
  });
}
