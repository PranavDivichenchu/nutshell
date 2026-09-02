# Nutshell

*What's actually in your food, in a nutshell.*

A SwiftUI app over the Open Food Facts database. iOS 17+, Swift concurrency, no third-party packages. Open `Nutshell.xcodeproj`; `⌘U` runs the tests.

## The thesis

Search plus a detail view makes a database browser. The question people actually have in a shop is narrower — **is this one right for me?** — so everything serves that.

Set your allergens and diets once in **You**, and every row, card, and detail screen is checked against them. **Scan** a barcode with the camera, or from a photo. **Compare** two or three products side by side, better figure in bold.

## What I prioritised

**Never implying safety from missing data.** Most Open Food Facts records carry no ingredient list. Reporting those as "safe" to someone avoiding milk would be the worst thing this app could do, so they resolve to *"Not enough data to tell"*. `maybe-vegan` is never rendered as vegan.

**Absorbing a hostile API.** The endpoint the brief names answers roughly one request in three with a 503 HTML page — measured, repeatedly. So the client sniffs non-JSON bodies, retries transient failures, and falls back to Search-a-licious, the backend Open Food Facts now recommends. Barcodes route to v2, and a partial record tops itself up from there when opened.

**Tests where the risk is** — decoding, the verdict engine, cancellation, and a `URLProtocol` stub reproducing the API's real failures. They caught an index crash on a malformed tag, a scanner deadlock, and a search that wedged forever when cancelled mid-flight.

## Tradeoffs

- Filters run over loaded results, not server-side. The UI says which it is.
- Camera scanning can't be verified in a Simulator; the photo path exists partly so the flow can be.
- iPhone only. Nothing here adapts to iPad width, so it doesn't claim to.
