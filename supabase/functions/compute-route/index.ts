// Proxies Google Routes API requests so the Google key stays server-side.
//
// Secret (never in the app):  supabase secrets set MAPS_API_KEY=...
//                             (GOOGLE_MAPS_API_KEY is also accepted, any casing)
// Deploy:                     supabase functions deploy compute-route
//
// Request  (POST JSON): { origin: {lat, lng}, destination: {lat, lng}, travelMode }
// Response (200 JSON):  { durationSeconds, distanceMeters, polyline }
//   404 { error: "no_route" } when Google finds no route for that mode.

const ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes";
const MODES = new Set(["DRIVE", "BICYCLE", "TRANSIT", "WALK", "TWO_WHEELER"]);

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

type Point = { lat: number; lng: number };

function parsePoint(p: unknown): Point | null {
  const o = p as Record<string, unknown> | null;
  if (!o || typeof o.lat !== "number" || typeof o.lng !== "number") return null;
  if (!Number.isFinite(o.lat) || !Number.isFinite(o.lng)) return null;
  if (o.lat < -90 || o.lat > 90 || o.lng < -180 || o.lng > 180) return null;
  return { lat: o.lat, lng: o.lng };
}

const toWaypoint = (p: Point) => ({
  location: { latLng: { latitude: p.lat, longitude: p.lng } },
});

// Secret names are case-sensitive; accept MAPS_API_KEY or GOOGLE_MAPS_API_KEY
// in any casing (e.g. Google_Maps_API_Key).
function googleKey(): string | undefined {
  for (const [name, value] of Object.entries(Deno.env.toObject())) {
    const n = name.toUpperCase();
    if (value && (n === "MAPS_API_KEY" || n === "GOOGLE_MAPS_API_KEY")) {
      return value;
    }
  }
  return undefined;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const key = googleKey();
  if (!key) return json({ error: "server_not_configured" }, 500);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const origin = parsePoint(body.origin);
  const destination = parsePoint(body.destination);
  const travelMode = String(body.travelMode ?? "DRIVE");
  if (!origin || !destination || !MODES.has(travelMode)) {
    return json({ error: "invalid_request" }, 400);
  }

  let res: Response;
  try {
    res = await fetch(ROUTES_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask":
          "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline",
      },
      body: JSON.stringify({
        origin: toWaypoint(origin),
        destination: toWaypoint(destination),
        travelMode,
      }),
    });
  } catch {
    return json({ error: "upstream_unreachable" }, 502);
  }

  if (!res.ok) {
    // Log the detail server-side; don't leak Google's message to clients.
    console.error("Routes API error", res.status, await res.text());
    return json({ error: "upstream_error" }, 502);
  }

  const data = await res.json();
  const route = data?.routes?.[0];
  if (!route) return json({ error: "no_route" }, 404);

  return json({
    durationSeconds: parseInt(String(route.duration).replace("s", ""), 10),
    distanceMeters: route.distanceMeters ?? 0,
    polyline: route.polyline?.encodedPolyline ?? "",
  });
});
