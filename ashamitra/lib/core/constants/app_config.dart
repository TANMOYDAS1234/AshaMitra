// AppConfig — Gemini is now called via backend proxy (/api/chat).
// The API key lives on the server (Render env var), never in the app.

class AppConfig {
  // No Gemini key in the app — all AI calls go through the backend proxy.
  static bool get hasGeminiKey => false;
}
