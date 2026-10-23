// Finds a place by name or address (businesses/POIs like "AMB Cinemas" as well
// as street addresses) using Google Places API (New) Text Search, so the
// Google key stays server-side.
//
// Secret (never in the app):  supabase secrets set MAPS_API_KEY=...
//                             (GOOGLE_MAPS_API_KEY is also accepted, any casing)
// Deploy:                     supabase functions deploy search-place
//
// Requests (POST JSON); `near` ({lat, lng}) biases results toward the user:
//   { query, near? }                      -> { lat, lng, name, address }
//   { op: "autocomplete", input, near?, token? }
//                                         -> { suggestions: [{id, main, secondary}] }
//   { op: "details", id, token? }         -> { lat, lng, name, address }
//   { op: "nearby", types: ["cafe"], near, radius? }
//   { op: "textsearch", query, near? }    -> { places: [PlaceItem] } (<= 20)
//     PlaceItem = { id, name, address, lat, lng, rating?, ratings?, open? }
// 404 { error: "not_found" } when nothing matches. `token` is a Places session
// token shared by the autocomplete calls and the details call that ends them.

const PLACES_URL = "https://places.googleapis.com/v1/places";
const SEARCH_URL = `${PLACES_URL}:searchText`;
const NEARBY_URL = `${PLACES_URL}:searchNearby`;
const AUTOCOMPLETE_URL = `${PLACES_URL}:autocomplete`;

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

const num = (v: unknown) =>
  typeof v === "number" && Number.isFinite(v) ? v : null;

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
  const near = body.near as Record<string, unknown> | undefined;
  const lat = num(near?.lat);
  const lng = num(near?.lng);
  const bias =
    lat !== null && lng !== null && Math.abs(lat) <= 90 && Math.abs(lng) <= 180
      ? {
          circle: { center: { latitude: lat, longitude: lng }, radius: 50000 },
        }
      : null;
  const token =
    typeof body.token === "string" && body.token.length <= 64
      ? body.token
      : undefined;

  if (body.op === "autocomplete") {
    const input = typeof body.input === "string" ? body.input.trim() : "";
    if (!input || input.length > 200) return json({ error: "invalid_query" }, 400);
    const res = await fetch(AUTOCOMPLETE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Goog-Api-Key": key },
      body: JSON.stringify({
        input,
        ...(bias ? { locationBias: bias } : {}),
        ...(token ? { sessionToken: token } : {}),
      }),
    });
    if (!res.ok) return json({ error: "places_failed" }, 502);
    const data = await res.json();
    const suggestions = (data?.suggestions ?? [])
      .map((x: Record<string, any>) => x.placePrediction)
      .filter((p: Record<string, any> | undefined) => p?.placeId)
      .slice(0, 5)
      .map((p: Record<string, any>) => ({
        id: p.placeId,
        main: p.structuredFormat?.mainText?.text ?? p.text?.text ?? "",
        secondary: p.structuredFormat?.secondaryText?.text ?? "",
      }));
    return json({ suggestions });
  }

  if (body.op === "nearby" || body.op === "textsearch") {
    const fields =
      "places.id,places.displayName,places.formattedAddress,places.location," +
      "places.rating,places.userRatingCount,places.currentOpeningHours";
    let url = SEARCH_URL;
    let payload: Record<string, unknown>;
    if (body.op === "nearby") {
      const types = Array.isArray(body.types)
        ? body.types.filter(
            (t): t is string => typeof t === "string" && /^[a-z_]{2,60}$/.test(t),
          ).slice(0, 5)
        : [];
      if (!types.length || lat === null || lng === null) {
        return json({ error: "invalid_request" }, 400);
      }
      const radius = Math.min(Math.max(num(body.radius) ?? 5000, 100), 50000);
      url = NEARBY_URL;
      payload = {
        // Primary type only (a bar that also serves food is not a restaurant)
        // and popularity ranking, so real businesses beat obscure listings.
        includedPrimaryTypes: types,
        maxResultCount: 20,
        rankPreference: "POPULARITY",
        locationRestriction: {
          circle: { center: { latitude: lat, longitude: lng }, radius },
        },
      };
    } else {
      const query = typeof body.query === "string" ? body.query.trim() : "";
      if (!query || query.length > 200) {
        return json({ error: "invalid_query" }, 400);
      }
      payload = {
        textQuery: query,
        pageSize: 20,
        ...(bias ? { locationBias: bias } : {}),
      };
    }
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": fields,
      },
      body: JSON.stringify(payload),
    });
    if (!res.ok) return json({ error: "places_failed" }, 502);
    const data = await res.json();
    // deno-lint-ignore no-explicit-any
    const places = (data?.places ?? []).filter((p: any) => p?.location).map(
      // deno-lint-ignore no-explicit-any
      (p: any) => ({
        id: p.id,
        name: p.displayName?.text ?? "",
        address: p.formattedAddress ?? "",
        lat: p.location.latitude,
        lng: p.location.longitude,
        rating: p.rating ?? null,
        ratings: p.userRatingCount ?? null,
        open: p.currentOpeningHours?.openNow ?? null,
      }),
    );
    return json({ places });
  }

  if (body.op === "details") {
    const id = typeof body.id === "string" ? body.id : "";
    if (!/^[A-Za-z0-9_-]{5,300}$/.test(id)) {
      return json({ error: "invalid_id" }, 400);
    }
    const url = new URL(`${PLACES_URL}/${id}`);
    if (token) url.searchParams.set("sessionToken", token);
    const res = await fetch(url, {
      headers: {
        "X-Goog-Api-Key": key,
        "X-Goog-FieldMask": "displayName,formattedAddress,location",
      },
    });
    if (!res.ok) return json({ error: "places_failed" }, 502);
    return placeJson(await res.json(), "");
  }

  const query = typeof body.query === "string" ? body.query.trim() : "";
  if (!query || query.length > 200) return json({ error: "invalid_query" }, 400);

  const res = await fetch(SEARCH_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": key,
      "X-Goog-FieldMask":
        "places.displayName,places.formattedAddress,places.location",
    },
    body: JSON.stringify({
      textQuery: query,
      pageSize: 1,
      ...(bias ? { locationBias: bias } : {}),
    }),
  });
  if (!res.ok) return json({ error: "places_failed" }, 502);
  const data = await res.json();
  return placeJson(data?.places?.[0], query);
});

// deno-lint-ignore no-explicit-any
function placeJson(p: any, fallbackName: string) {
  if (!p?.location) return json({ error: "not_found" }, 404);
  return json({
    lat: p.location.latitude,
    lng: p.location.longitude,
    name: p.displayName?.text ?? fallbackName,
    address: p.formattedAddress ?? "",
  });
}
