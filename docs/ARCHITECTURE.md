# Architecture

The project is organized by feature. Each feature separates presentation, application logic, domain contracts, and external integrations where needed. Small features do not have empty layers.

```text
lib/
  main.dart                         # Flutter bootstrap and dependency wiring
  app.dart                          # Theme, directionality, app composition
  core/storage/                     # Settings contract and SharedPreferences adapter
  features/
    browser/
      domain/browser_engine.dart    # Navigation and JavaScript runtime contracts
      application/browser_session.dart
      infrastructure/               # InAppWebView adapter and demo page
      presentation/                 # Screen and reusable address/result widgets
    scripts/
      domain/                       # Typed files, documents, config, domain routing
      data/                         # GitHub Contents API adapter
      application/                  # Script runner, catalog cache, discovery state
      presentation/                 # Repository, editor, picker and discovery UI
    protection/
      domain/                       # Local ad rules and matching policy
      presentation/                 # Protection settings dialog
```

## Boundaries

- Widgets own text controllers, dialog layout, and user-facing notifications. They do not issue HTTP requests or access preferences.
- `BrowserSession` owns use cases and observable browser state. It depends on `BrowserEngine`, `SettingsStore`, and a `ScriptRepositoryFactory`; tests replace these with fakes.
- `BrowserWeb` implements `BrowserEngine` and keeps plugin-specific configuration, request interception, and callbacks in one adapter. Replacing WebView does not require rewriting the script runner or storage.
- `GitHubScriptRepository` is the only production HTTP integration. It returns typed `ScriptFile` values and raises `ScriptRepositoryException` for API failures.
- `ScriptRunner` wraps asynchronous page JavaScript, polls the result, notices page changes, and always attempts cleanup. It does not depend on Flutter widgets or the plugin.
- `SiteScriptsController` owns domain discovery. `DomainScriptCatalog` caches directory lists by repo/ref/folder/domain. Script bodies are fetched again on selection. Generation checks discard late responses after navigation or repository changes.

## Domain-based discovery

On page completion, a configured repository is queried at `<root>/<normalized-host>/`. Normalization removes a leading `www.` and trailing dot, ignores ports, and preserves other subdomains. A missing directory is an empty result; other API failures are visible and can be retried. Refresh bypasses the list cache.

Selected remote documents carry their domain. Execution is disabled when the current domain differs. A slow source download cannot replace the selection after navigation. Editor content and script name/domain are persisted together. Legacy editor content without a domain remains usable as a manually supplied script.

## Persistence and lifecycle

`PreferencesSettingsStore` retains the original keys (`repo`, `branch`, `folder`, `code`, `adBlockEnabled`, `adBlockAllowedSites`, `adBlockCustomDomains`) and adds script name/domain. Existing installs retain their settings. No tokens are stored in repository files.

Every stateful dialog creates and disposes its own controllers. Session and discovery objects reject late results after disposal. Script execution is serialized by the session; runtime cancellation stops polling, while navigating or reloading destroys the old page context. A synchronous infinite JavaScript loop cannot be safely interrupted by the polling timeout.

## Extending the project

- Add a new source provider by implementing `ScriptRepository`; inject its factory at the composition root.
- Change preferences storage by implementing `SettingsStore`, preserving migration behavior.
- Add ad domains in `features/protection/domain/ad_blocker.dart` and matching tests.
- Add UI in feature presentation folders; keep validation and business decisions testable without WebView.

The InAppWebView beta is pinned for AGP 9 ProGuard compatibility. Upgrade it deliberately and rerun the device tests before changing the lock file.
