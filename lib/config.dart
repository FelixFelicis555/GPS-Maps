/// Supabase project used to proxy Google Routes API calls (the Google key is a
/// Supabase secret named MAPS_API_KEY and never ships in the app).
/// Both values are public by design (the anon key is not a secret).
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get routingConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

/// Optional, used only by the Translator for Google Cloud Translation. Leave
/// unset to use the free MyMemory fallback. Anything passed here ships inside
/// the app, so restrict it in Google Cloud Console.
const kMapsApiKey = String.fromEnvironment('MAPS_API_KEY');
// Android map tiles read MAPS_API_KEY from android/local.properties; iOS reads
// it in ios/Runner/AppDelegate.swift (restrict those keys to the Maps SDKs).
