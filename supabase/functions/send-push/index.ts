// VIBE — push bildiriş göndərən Supabase Edge Function.
//
// NİYƏ: Firebase Cloud Functions pullu "Blaze" planı tələb edir.
// Supabase Edge Functions isə pulsuz tarifə daxildir, ona görə göndərmə
// tərəfi buraya köçürülüb. Müştəri bu funksiyaya müraciət edir,
// funksiya isə FCM HTTP v1 API-sinə göndərir.
//
// QURAŞDIRMA (bir dəfə):
//   1. Firebase Console → Project settings → Service accounts →
//      "Generate new private key" → JSON faylı endir.
//   2. supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
//      supabase secrets set FIREBASE_API_KEY="<Web API Key>"
//   3. supabase functions deploy send-push
//   4. Alınan URL-i `lib/push_send.dart` içindəki `pushFunctionUrl`-a yaz.
//
// TƏHLÜKƏSİZLİK: göndərən Firebase ID tokeni ilə təsdiqlənir —
// yalnız giriş etmiş istifadəçi bildiriş göndərə bilər və göndərən
// kimliyi tokendən götürülür, müştərinin yazdığına inanılmır.

import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function serviceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT təyin edilməyib");
  return JSON.parse(raw) as ServiceAccount;
}

/** Service account ilə FCM üçün OAuth2 access token alır. */
let cachedToken: { value: string; expires: number } | null = null;

async function accessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expires > now + 60) return cachedToken.value;

  const key = await importPKCS8(account.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const json = await response.json();
  if (!response.ok) throw new Error(`OAuth xətası: ${JSON.stringify(json)}`);

  cachedToken = {
    value: json.access_token as string,
    expires: now + (json.expires_in as number),
  };
  return cachedToken.value;
}

/** Göndərənin Firebase ID tokenini yoxlayır, uid və adını qaytarır. */
async function verifyCaller(
  idToken: string,
): Promise<{ uid: string; name: string }> {
  const apiKey = Deno.env.get("FIREBASE_API_KEY");
  if (!apiKey) throw new Error("FIREBASE_API_KEY təyin edilməyib");

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${apiKey}`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ idToken }),
    },
  );

  const json = await response.json();
  const user = json?.users?.[0];
  if (!response.ok || !user) throw new Error("Giriş tokeni etibarsızdır");

  return { uid: user.localId as string, name: (user.displayName ?? "") as string };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    const authorization = request.headers.get("authorization") ?? "";
    const idToken = authorization.replace(/^Bearer\s+/i, "").trim();
    if (!idToken) throw new Error("Authorization başlığı yoxdur");

    const caller = await verifyCaller(idToken);

    const body = await request.json();
    const tokens: string[] = Array.isArray(body.tokens) ? body.tokens : [];
    const title = String(body.title ?? "VIBE");
    const message = String(body.body ?? "");

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), {
        headers: { ...CORS, "content-type": "application/json" },
      });
    }

    const account = serviceAccount();
    const bearer = await accessToken(account);
    const endpoint =
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

    // Göndərən kimliyi HƏMİŞƏ tokendən götürülür.
    const data: Record<string, string> = {
      fromUid: caller.uid,
      fromName: String(body.fromName ?? caller.name ?? ""),
      type: String(body.type ?? "message"),
    };

    const results = await Promise.all(
      tokens.slice(0, 20).map((token) =>
        fetch(endpoint, {
          method: "POST",
          headers: {
            authorization: `Bearer ${bearer}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body: message },
              data,
              android: { priority: "HIGH" },
              apns: {
                payload: { aps: { sound: "default", badge: 1 } },
              },
            },
          }),
        }).then((r) => r.ok)
      ),
    );

    return new Response(
      JSON.stringify({ sent: results.filter(Boolean).length }),
      { headers: { ...CORS, "content-type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `${error}` }),
      { status: 400, headers: { ...CORS, "content-type": "application/json" } },
    );
  }
});
