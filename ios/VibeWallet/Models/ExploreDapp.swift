import Foundation

struct ExploreDapp: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let url: String
}

struct ExploreCategory: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [ExploreDapp]
}
