import Foundation

#if DEBUG
/// A canned `FoodFactsService` for SwiftUI previews and tests.
///
/// Previews that hit the real network are slow, flaky, and — against an endpoint that
/// rate-limits this hard — actively counterproductive.
struct PreviewFoodFactsService: FoodFactsService {
    var result: Result<SearchPage, Error> = .success(.preview)
    var delay: Duration = .milliseconds(400)

    func search(_ query: String, page: Int) async throws -> SearchPage {
        try await Task.sleep(for: delay)
        return try result.get()
    }
}

extension SearchPage {
    static let preview = SearchPage(
        products: Product.previews,
        page: 1,
        totalCount: Product.previews.count,
        hasMorePages: false
    )
}

extension Product {
    /// Decoded from real API payloads so previews exercise the same decoding path as
    /// production, including the sparse records the UI has to survive.
    static let previews: [Product] = {
        let json = """
        [
          {
            "code": "7394376616228",
            "product_name": "Oatly Barista Edition Oat Drink",
            "brands": "Oatly",
            "quantity": "1 l",
            "serving_size": "100 ml",
            "image_front_url": "https://images.openfoodfacts.org/images/products/739/437/661/6228/front_en.197.400.jpg",
            "image_front_small_url": "https://images.openfoodfacts.org/images/products/739/437/661/6228/front_en.197.200.jpg",
            "nutriscore_grade": "d",
            "ecoscore_grade": "b",
            "nova_group": 3,
            "ingredients_text": "Water, oats 10%, rapeseed oil, acidity regulator (dipotassium phosphate), minerals (calcium carbonate, potassium iodide), salt, vitamins (D2, riboflavin, B12)",
            "allergens_tags": ["en:gluten"],
            "additives_tags": ["en:e340"],
            "labels_tags": ["en:vegan", "en:no-milk"],
            "categories_tags": ["en:beverages", "en:plant-based-foods"],
            "ingredients_analysis_tags": ["en:palm-oil-free", "en:vegan", "en:vegetarian"],
            "nutrient_levels": {"fat": "moderate", "salt": "low", "saturated-fat": "low", "sugars": "moderate"},
            "nutriments": {
              "energy-kcal_100g": 61, "fat_100g": 3, "saturated-fat_100g": 0.3,
              "carbohydrates_100g": 7.1, "sugars_100g": 3.4, "fiber_100g": 0.8,
              "proteins_100g": 1.1, "salt_100g": 0.0975,
              "energy-kcal_serving": 61, "fat_serving": "3", "sugars_serving": 3.4,
              "proteins_serving": 1.1, "salt_serving": 0.0975, "fat_unit": "g"
            }
          },
          {
            "code": "3017620422003",
            "product_name": "Nutella",
            "brands": "Ferrero",
            "quantity": "400 g",
            "nutriscore_grade": "e",
            "nova_group": "4",
            "ingredients_text": "Sugar, palm oil, hazelnuts 13%, skimmed milk powder 8.7%, fat-reduced cocoa 7.4%, emulsifier: lecithins (soya), vanillin",
            "allergens_tags": ["en:milk", "en:nuts", "en:soybeans"],
            "ingredients_analysis_tags": ["en:vegetarian"],
            "nutrient_levels": {"fat": "high", "salt": "low", "saturated-fat": "high", "sugars": "high"},
            "nutriments": {
              "energy-kcal_100g": 539, "fat_100g": 30.9, "saturated-fat_100g": 10.6,
              "carbohydrates_100g": 57.5, "sugars_100g": 56.3, "proteins_100g": 6.3, "salt_100g": 0.107
            }
          },
          {
            "code": "0000000000017",
            "product_name": "Store-brand crackers",
            "nutriments": {}
          }
        ]
        """
        return (try? JSONDecoder().decode([Product].self, from: Data(json.utf8))) ?? []
    }()
}
#endif
