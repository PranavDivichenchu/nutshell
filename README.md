# Nutshell

*What's actually in your food, in a nutshell.*

A SwiftUI app over the Open Food Facts database. iOS 17+, Swift concurrency, no third-party packages. Open `Nutshell.xcodeproj`; `⌘U` runs the tests.

## The thesis

Search plus a detail view makes a database browser. The question people actually have in a shop is narrower — **is this one right for me?** — so everything serves that.

Set your allergens and diets once in **You**, and every row, card, and detail screen is checked against them. **Scan** a barcode with the camera, or from a photo. **Compare** two or three products side by side, better figure in bold.

## What I prioritised

**Never implying safety from missing data.** Most Open Food Facts records carry no ingredient list. Reporting those as "safe" to someone avoiding milk would be the worst thing this app could do, so they resolve to *"Not enough data to tell"*. `maybe-vegan` is likewise never rendered as vegan.

**Absorbing a hostile API.** The search endpoint answers roughly one request in three with a 503 HTML page. The client sniffs non-JSON bodies and retries transient failures; `fields=` cuts a page from ~1 MB to ~3 KB; barcodes route to the far more reliable v2 endpoint.

**Tests where the risk is** — decoding, the verdict engine, filters, and a `URLProtocol` stub that forces the exact failures the real API produces. They caught two real bugs: an index crash on a malformed tag, and a deadlock in the scanner.

## Tradeoffs

- Filters run over loaded results, not server-side. The API's own filtering is slow and unreliable; the UI says which it is.
- Camera scanning can't be verified in a Simulator. The photo path exists partly so the flow can be.
- No accounts or sync — out of scope here.
