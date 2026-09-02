# Nutshell

An iOS app for looking up food on Open Food Facts.

SwiftUI, iOS 17+, no third-party packages. Open `Nutshell.xcodeproj` and run it. ⌘U runs the tests.

## What it does

Search for a product, tap it, see what's in it.

You can also set your allergens and diets once in the You tab. After that every search result and product page gets checked against them, so you can tell whether something has milk in it without reading the whole ingredient list.

There's a barcode scanner, which works off the camera or off a photo. And a compare screen for putting two or three products next to each other.

## Why I built it this way

Most products in Open Food Facts are missing most of their data. If you avoid milk and a product has no ingredient list, the app says "not enough data to tell" instead of showing a green tick. I didn't want it guessing about that.

The search endpoint in the brief is unreliable. Roughly one request in three came back as a 503 HTML page while I was testing. I kept it as the default and added the newer Search-a-licious backend underneath it as a fallback. Barcode lookups go to the v2 endpoint, which never failed on me.

There are 106 tests, mostly covering the parsing and the allergen logic. They found a crash on a malformed tag and a search that would spin forever if you switched tabs while it was loading.

## Known limits

Filters apply to the results already loaded, not to the whole database.

Camera scanning can't be tested in the simulator. That's partly why the photo option exists.

iPhone only. Nothing here is laid out for an iPad.
