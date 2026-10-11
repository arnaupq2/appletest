# VoiceCache native API

The Expo native module stores independent voice assets under the iOS Caches directory. It is a cache, not durable storage: iOS may purge it.

## JavaScript API

- `await VoiceCache.getStatus()` returns `files`, `bytes`, `maxBytes`, `maxAgeSeconds`, and `evictionPolicy`.
- `await VoiceCache.cleanup()` expires entries not accessed for 50 minutes and applies the size limit.
- `await VoiceCache.storeVoiceAsset(assetName, base64)` stores/replaces one asset. Assets larger than 20 MiB are rejected.
- `await VoiceCache.getVoiceAsset(assetName)` returns Base64 or `null`; successful reads refresh the inactivity timer.
- `await VoiceCache.deleteVoiceAsset(assetName)` removes one entry.
- `await VoiceCache.clear()` removes all cached entries at the user's request.

## Policy

Every file is one entry. The inactivity TTL is 50 minutes, refreshed on read. The aggregate limit is 20 MiB. When the aggregate size exceeds the limit, the least-recently-used entries are removed until it fits; the cache is not wiped wholesale.

## Important scope

This module only stores and expires assets. It does not extract speaker embeddings, diarize audio, clone a voice, or synthesize speech. Those require an actual on-device audio model and an audio-sample pipeline; Apple Foundation Models is a text model and cannot provide those audio capabilities by itself.
