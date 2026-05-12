{{/*
  HTML body for the error-page service. Rendered once per status code by
  configmap.yaml. The page is intentionally static (no JS) and uses inline
  CSS so it works without external network access.
*/}}
{{- define "auth.errorPage.html" -}}
{{- $brand := .brand -}}
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{ .code }} — {{ .title }}</title>
<style>
  :root {
    color-scheme: dark;
    --bg: {{ $brand.backgroundColor }};
    --fg: {{ $brand.textColor }};
    --accent: {{ $brand.primaryColor }};
  }
  html, body { height: 100%; margin: 0; }
  body {
    background: var(--bg);
    color: var(--fg);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Inter, sans-serif;
    display: grid;
    place-items: center;
    padding: 2rem;
    line-height: 1.5;
  }
  .card {
    max-width: 28rem;
    text-align: center;
  }
  .code {
    font-size: clamp(4rem, 12vw, 7rem);
    font-weight: 700;
    color: var(--accent);
    letter-spacing: -0.04em;
    margin: 0;
  }
  h1 {
    font-size: 1.5rem;
    font-weight: 600;
    margin: 0.5rem 0 1rem;
  }
  p {
    margin: 0 0 1.5rem;
    opacity: 0.8;
  }
  .actions {
    display: flex;
    gap: 0.75rem;
    justify-content: center;
    flex-wrap: wrap;
  }
  a {
    color: var(--accent);
    text-decoration: none;
    font-weight: 500;
    border: 1px solid var(--accent);
    border-radius: 0.5rem;
    padding: 0.5rem 1rem;
    display: inline-block;
  }
  a:hover { background: var(--accent); color: var(--bg); }
  a.secondary {
    color: var(--fg);
    border-color: rgba(255,255,255,0.2);
    opacity: 0.7;
  }
  a.secondary:hover { background: transparent; color: var(--fg); opacity: 1; border-color: rgba(255,255,255,0.5); }
  .meta {
    margin-top: 2rem;
    font-size: 0.8rem;
    opacity: 0.4;
  }
</style>
</head>
<body>
<main class="card">
  <p class="code">{{ .code }}</p>
  <h1>{{ .title }}</h1>
  <p>{{ .msg }}</p>
  <div class="actions">
    {{/*
      Primary: go back to the page the user was on (history.back).
      Falls back to the configured home URL when there is no history
      entry (e.g. the error page was opened in a new tab) or when
      JavaScript is disabled — same href the anchor would have used.
    */}}
    <a id="back" href="{{ .homeUrl }}" onclick="if(history.length>1){history.back();return false;}">Go back</a>
    <a class="secondary" href="{{ .homeUrl }}">{{ .appName }} home</a>
  </div>
  {{- if $brand.supportEmail }}
  <p class="meta">Need help? <a href="mailto:{{ $brand.supportEmail }}" style="border:none;padding:0;">{{ $brand.supportEmail }}</a></p>
  {{- end }}
</main>
</body>
</html>
{{- end -}}
