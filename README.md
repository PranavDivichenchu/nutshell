# Open Food Facts Explorer

A SwiftUI app for searching the Open Food Facts database. iOS 17+, Swift concurrency, no third-party packages. Open `OpenFoodFacts.xcodeproj` and run.

## What I prioritized

**Handling the data honestly.** Open Food Facts is volunteer-contributed, so records are wildly uneven — the same field arrives as `3`, `3.0`, or `"3"`, and most products are missing something. Decoding absorbs that at the boundary (`LenientValues.swift`) so the rest of the app uses plain optionals, and every detail section omits itself when empty rather than rendering blank scaffolding.

**Making the API's flakiness invisible.** Their search endpoint answers roughly one request in three with a 503 HTML page — including requests it served seconds earlier. The client sniffs for non-JSON bodies, retries transient failures twice with backoff, and only then shows an error saying what actually happened. It also requests `fields=`, cutting a 20-result page from ~1 MB to ~3 KB.

**Search that doesn't hammer the endpoint.** `.task(id: query)` drives a 350 ms debounce, so SwiftUI's cancellation *is* the debounce — no timers to invalidate. Results prefetch three rows before the end.

## What I added

Nutri-Score, NOVA, and Eco-Score drawn as their real on-pack scales; traffic-light nutrient levels; a nutrition table with a per-100 g / per-serving toggle that appears only when serving data exists; ingredients with declared allergens highlighted by whole word; saved products persisted in full, so that tab works offline; recent searches.

## Tradeoffs

- **No unit tests.** The lenient decoding is what I'd test first. I spent that time on the decoding itself and on preview fixtures built from real payloads.
- **No barcode scanner.** The obvious next feature, but not verifiable in the simulator.
- **No compare view.** Cut deliberately: it doubles the surface area for something most searches don't need.
