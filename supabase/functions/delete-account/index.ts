import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const allowedBrowserOrigins = new Set([
  'https://www.fusionventuresglobal.com',
  'https://fusionventuresglobal.com',
  'http://localhost:3000',
  'http://127.0.0.1:3000',
]);

function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin');
  return {
    ...(origin && allowedBrowserOrigins.has(origin)
      ? { 'Access-Control-Allow-Origin': origin }
      : {}),
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
}

function response(request: Request, status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), 'Content-Type': 'application/json' },
  });
}

async function listOwnedObjects(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const paths: string[] = [];
  let offset = 0;
  while (true) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: 1000,
      offset,
    });
    if (error) throw error;
    if (!data?.length) return paths;
    for (const item of data) {
      const path = `${prefix}/${item.name}`;
      if (item.id) {
        paths.push(path);
      } else {
        paths.push(...await listOwnedObjects(admin, bucket, path));
      }
    }
    if (data.length < 1000) return paths;
    offset += data.length;
  }
}

async function deleteSharedRecordNotifications(
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<void> {
  // Notifications addressed to the other participant do not cascade when a
  // candidate is deleted. Remove only notifications whose source is one of
  // this account's shared records, before those source rows are cascaded.
  const { data: interests, error: interestsError } = await admin
    .from('interest_requests')
    .select('id')
    .eq('candidate_id', userId);
  if (interestsError) throw interestsError;

  const { data: matches, error: matchesError } = await admin
    .from('matches')
    .select('id')
    .eq('candidate_id', userId);
  if (matchesError) throw matchesError;

  const interestIds = (interests ?? []).map((item) => item.id);
  const matchIds = (matches ?? []).map((item) => item.id);
  const { data: messages, error: messagesError } = matchIds.length === 0
    ? { data: [], error: null }
    : await admin.from('chat_messages').select('id').in('match_id', matchIds);
  if (messagesError) throw messagesError;

  const deleteBySource = async (sourceType: string, ids: string[]) => {
    if (ids.length === 0) return;
    const { error } = await admin
      .from('notifications')
      .delete()
      .eq('source_type', sourceType)
      .in('source_id', ids);
    if (error) throw error;
  };

  await deleteBySource('interest_requests', interestIds);
  await deleteBySource('matches', matchIds);
  await deleteBySource(
    'chat_messages',
    (messages ?? []).map((item) => item.id),
  );
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(request) });
  if (request.method !== 'POST') return response(request, 405, { error: 'Method not allowed' });

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return response(request, 401, { error: 'Authentication required' });
  }

  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const admin = createClient(url, serviceRoleKey);
  const token = authorization.substring('Bearer '.length);
  const { data: userData, error: userError } = await caller.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return response(request, 401, { error: 'Authentication required' });

  try {
    // Every KAAM upload is written beneath auth.users.id. Never accept a user
    // ID from the client, which prevents cross-account storage deletion.
    for (const bucket of ['kaam-private', 'kaam-public']) {
      const paths = await listOwnedObjects(admin, bucket, user.id);
      for (let index = 0; index < paths.length; index += 100) {
        const { error } = await admin.storage.from(bucket).remove(paths.slice(index, index + 100));
        if (error) throw error;
      }
    }

    await deleteSharedRecordNotifications(admin, user.id);

    // Deleting auth.users is deliberately last. profiles references it with
    // ON DELETE CASCADE, which removes candidate/employer profiles, documents,
    // matches/chat, preferences, notifications, FCM devices, and related rows.
    const { error } = await admin.auth.admin.deleteUser(user.id);
    if (error) throw error;
    return response(request, 200, { ok: true });
  } catch (error) {
    console.error('account deletion failed', error instanceof Error ? error.name : 'unknown');
    return response(request, 500, { error: 'Unable to delete the account. Please try again or contact support.' });
  }
});
