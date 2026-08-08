#!/usr/bin/env node
// JSON builders for crouter's local proxies. Pure stdin/env -> stdout; no
// network, no filesystem writes except the explicit `combine` output path.
//
// Split out of bin/crouter so the route/candidate shapes live in one readable,
// testable place instead of several inline `node -e '...'` blocks.
//
//   candidates        One provider's gateway route object (NDJSON line) from
//                     the CR_* env contract below. Prints nothing when the
//                     provider has no usable credential.
//   surface-candidates  Explicit Token Plan/API Key candidate array. Every
//                     credential remains bound to its declared surface.
//   dual-candidates   keypool-proxy candidate array for a dual-source direct
//                     launch (default account first, API key second).
//   combine <in> <out>  NDJSON route lines -> pretty-printed JSON array.
//   default-model <routes.json>  "<prefix>/<first model>" of the first route.
//
// Env contract (all optional, empty means "not configured"):
//   CR_PREFIX          provider name, used as the "<provider>/" model prefix
//   CR_MODELS          whitespace-separated model names (deduped here, order kept)
//   CR_KEYPOOL_KEYS    whitespace-separated keypool secrets; when non-empty every
//                      key becomes its own candidate and the surfaces below are
//                      ignored
//   CR_SURFACE_CANDIDATES  explicit candidate JSON from `surface-candidates`
//   CR_MODEL[_OPUS|_SONNET|_HAIKU|_SUBAGENT]  public/logical tier IDs
//   CR_PLAN_URL / CR_PLAN_TYPE / CR_PLAN_TOKENS
//   CR_PLAN_MODEL[_OPUS|_SONNET|_HAIKU|_SUBAGENT] upstream plan tier IDs
//   CR_API_URL / CR_API_TYPE / CR_API_TOKENS
//   CR_API_MODEL[_OPUS|_SONNET|_HAIKU|_SUBAGENT] upstream API tier IDs
//   CR_DEFAULT_URL / CR_DEFAULT_TYPE / CR_DEFAULT_TOKEN   preferred surface
//   CR_API_URL / CR_API_TYPE / CR_API_KEY                 fallback surface
//   CR_AUTH_MODE       provider AUTH_MODE, only "none" is special-cased
//   CR_AUTH_SCHEME     provider _AUTH_SCHEME, used when CR_API_TYPE is unset
//   CR_NONE_TOKEN       dummy token for AUTH_MODE=none

'use strict';

const fs = require('fs');

const env = (name) => process.env[name] || '';
const words = (value) => value.split(/\s+/).filter(Boolean);

// Candidates are tried in order; the proxy rotates on auth/quota failures.
function buildCandidates() {
  const defaultUrl = env('CR_DEFAULT_URL');
  const apiUrl = env('CR_API_URL');
  const keypool = words(env('CR_KEYPOOL_KEYS'));

  if (env('CR_SURFACE_CANDIDATES')) {
    let surfaceCandidates;
    try {
      surfaceCandidates = JSON.parse(env('CR_SURFACE_CANDIDATES'));
    } catch (error) {
      throw new Error('CR_SURFACE_CANDIDATES is not valid JSON: ' + error.message);
    }
    if (!Array.isArray(surfaceCandidates)) {
      throw new Error('CR_SURFACE_CANDIDATES must be an array');
    }
    return surfaceCandidates.map((candidate) => ({
      url: candidate.url,
      auth: {type: candidate.type, token: candidate.token},
      model_map: candidate.model_map || {},
      extra_env: [],
    }));
  }

  // keypool: every key is its own candidate (order: main keys, then plus keys).
  if (keypool.length) {
    return keypool.map((token) => ({
      url: apiUrl,
      auth: { type: 'x-api-key', token },
      extra_env: [],
    }));
  }

  const candidates = [];
  // dual-source: preferred account first, API key fallback.
  if (env('CR_DEFAULT_TOKEN')) {
    candidates.push({
      url: defaultUrl,
      auth: { type: env('CR_DEFAULT_TYPE') || 'bearer', token: env('CR_DEFAULT_TOKEN') },
      extra_env: [],
    });
  }
  if (env('CR_API_KEY')) {
    // The provider may declare its header shape either as a dual-source
    // API_AUTH_TYPE or as the single-surface _AUTH_SCHEME; both mean the same
    // thing here.
    candidates.push({
      url: apiUrl,
      auth: {
        type: env('CR_API_TYPE') || env('CR_AUTH_SCHEME') || 'x-api-key',
        token: env('CR_API_KEY'),
      },
      extra_env: [],
    });
  } else if (env('CR_AUTH_MODE') === 'none') {
    // No credential at all (e.g. Ollama): pass the dummy token and whatever
    // EXTRA_ENV the provider needs on the wire.
    candidates.push({
      url: apiUrl,
      auth: { type: 'none', token: env('CR_NONE_TOKEN') },
      extra_env: [],
    });
  }
  return candidates;
}

function surfaceCandidates() {
  const candidates = [];
  const tierSuffixes = ['', '_OPUS', '_SONNET', '_HAIKU', '_SUBAGENT'];
  const modelMap = (surfacePrefix) => {
    const result = {};
    const surfaceDefault = env('CR_' + surfacePrefix + '_MODEL');
    for (const suffix of tierSuffixes) {
      const logical = env('CR_MODEL' + suffix);
      const upstream = env('CR_' + surfacePrefix + '_MODEL' + suffix) || (suffix ? surfaceDefault : '');
      if (!logical || !upstream) continue;
      if (Object.prototype.hasOwnProperty.call(result, logical) && result[logical] !== upstream) {
        throw new Error(
          surfacePrefix.toLowerCase() + ' model map is ambiguous for ' + JSON.stringify(logical),
        );
      }
      result[logical] = upstream;
    }
    return result;
  };
  const append = (surface, surfacePrefix, url, type, tokens) => {
    if (!url) return;
    const map = modelMap(surfacePrefix);
    words(tokens).forEach((token, index) => {
      candidates.push({
        url,
        type: type || 'bearer',
        token,
        model_map: map,
        label: surface + '-' + (index + 1),
      });
    });
  };
  append('token-plan', 'PLAN', env('CR_PLAN_URL'), env('CR_PLAN_TYPE'), env('CR_PLAN_TOKENS'));
  append('api-key', 'API', env('CR_API_URL'), env('CR_API_TYPE'), env('CR_API_TOKENS'));
  return candidates;
}

function cmdSurfaceCandidates() {
  process.stdout.write(JSON.stringify(surfaceCandidates()));
}

function cmdCandidates() {
  const candidates = buildCandidates();
  if (candidates.length === 0) return; // no credential -> provider is skipped
  const models = [...new Set(words(env('CR_MODELS')))];
  process.stdout.write(
    JSON.stringify({
      prefix: env('CR_PREFIX'),
      base_url: env('CR_API_URL') || env('CR_PLAN_URL') || env('CR_DEFAULT_URL'),
      candidates,
      models,
    }) + '\n',
  );
}

// keypool-proxy's candidate-mode contract is a flatter shape than the gateway's.
function cmdDualCandidates() {
  const candidates = [];
  if (env('CR_DEFAULT_TOKEN')) {
    candidates.push({
      url: env('CR_DEFAULT_URL'),
      type: env('CR_DEFAULT_TYPE'),
      token: env('CR_DEFAULT_TOKEN'),
      label: 'default-account',
    });
  }
  if (env('CR_API_KEY')) {
    candidates.push({
      url: env('CR_API_URL'),
      type: env('CR_API_TYPE'),
      token: env('CR_API_KEY'),
      label: 'api-key',
    });
  }
  process.stdout.write(JSON.stringify(candidates));
}

function cmdCombine(inPath, outPath) {
  const routes = fs
    .readFileSync(inPath, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => JSON.parse(line));
  fs.writeFileSync(outPath, JSON.stringify(routes, null, 2));
}

function cmdDefaultModel(routesPath) {
  const routes = JSON.parse(fs.readFileSync(routesPath, 'utf8'));
  const first = routes[0];
  const prefix = (first && first.prefix) || '';
  const model = (first && first.models && first.models[0]) || '';
  process.stdout.write(prefix + '/' + model);
}

const [subcommand, ...args] = process.argv.slice(2);
switch (subcommand) {
  case 'surface-candidates':
    cmdSurfaceCandidates();
    break;
  case 'candidates':
    cmdCandidates();
    break;
  case 'dual-candidates':
    cmdDualCandidates();
    break;
  case 'combine':
    cmdCombine(args[0], args[1]);
    break;
  case 'default-model':
    cmdDefaultModel(args[0]);
    break;
  default:
    process.stderr.write('route-build.js: unknown subcommand ' + JSON.stringify(subcommand || '') + '\n');
    process.exit(2);
}
