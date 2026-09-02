# Nutshell

An iOS app for looking up what's actually in your food.

SwiftUI, iOS 17+, no third-party packages. Open `Nutshell.xcodeproj` and run it. ⌘U runs the tests.

## What it does

You search for a product and tap it to see what's in it.

The part I actually built it around is different. You set your allergens and diets once in the You tab, and after that every result and product page gets checked against them. If something has milk in it you see that on the row, before you open it.

There's also a barcode scanner that reads from the camera or a photo, and a compare screen for putting two or three products side by side.

## Why I built it this way

Most of Open Food Facts is missing data. Volunteers fill it in, so plenty of products have a name and nothing else. If you avoid milk and a product has no ingredient list, the app says it can't check instead of showing a green tick. I'd rather it admit that than be confidently wrong about an allergy.

Browsing and searching are deliberately separate. Typing "cereal" matches names, brands and ingredients, so you get cereal bars and cookies mixed in. The Cereal tile filters the real category and returns corn flakes and muesli.

The search endpoint in the brief goes down constantly. Roughly one in three requests came back as a 503, so I kept it as the default and put the newer Search-a-licious backend behind it. Barcodes go to the v2 endpoint, which never failed on me.

Filters run over results you already have rather than going back to the API, which is unreliable enough as it is.

I wrote 108 tests, mostly around parsing and the allergen logic, since that's where being wrong costs something.
