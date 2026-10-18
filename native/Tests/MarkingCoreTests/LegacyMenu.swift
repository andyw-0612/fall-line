#if canImport(MarkingCore)
import MarkingCore
#endif

// Dense sample tree retained only to exercise every direction/repeat combination.
extension MenuNode {
    static let testRoot: MenuNode = {
        let groups: [(String, [(String, [String])])] = [
            ("Food", [("Fruit", ["Apple", "Pear", "Peach"]), ("Bakery", ["Bread", "Croissant", "Bagel"]), ("Dessert", ["Cake", "Ice cream", "Cookie"])]),
            ("Tools", [("Cutting", ["Saw", "Scissors", "Knife"]), ("Fastening", ["Hammer", "Wrench", "Screwdriver"]), ("Measuring", ["Ruler", "Level", "Tape measure"])]),
            ("Animals", [("Wild", ["Fox", "Bear", "Deer"]), ("Pets", ["Cat", "Dog", "Rabbit"]), ("Birds", ["Owl", "Robin", "Eagle"])]),
            ("Vehicles", [("Land", ["Bicycle", "Car", "Train"]), ("Water", ["Sailboat", "Kayak", "Ferry"]), ("Air", ["Plane", "Glider", "Helicopter"])])
        ]
        return MenuNode(id: "root", name: "Explore", children: groups.enumerated().map { i, group in
            MenuNode(id: "category-\(i)", name: group.0, children: group.1.enumerated().map { j, branch in
                MenuNode(id: "branch-\(i)-\(j)", name: branch.0, children: branch.1.enumerated().map { k, name in
                    MenuNode(id: "leaf-\(i)-\(j)-\(k)", name: name, children: [])
                })
            })
        })
    }()
}

extension StrokeRecognizer {
    static func testVertices(_ points: [Point]) -> [GestureVertex]? { vertices(points, root: .testRoot) }
}
