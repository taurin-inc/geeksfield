import Foundation

struct IterationRun: Identifiable, Hashable, Sendable {
    let id: String
    let projectID: String
    let prompt: String
    let createdAt: Date
    let latestAt: Date
    let parentImageID: String?
    let referenceIDs: [String]
    let operation: ImageOperation
    let assets: [ImageAsset]

    static func group(_ assets: [ImageAsset]) -> [IterationRun] {
        let grouped = Dictionary(grouping: assets) { asset in
            asset.metadata.runID ?? asset.id
        }

        return grouped.compactMap { runID, items in
            guard let first = items.sorted(by: sortAssetsForRun).first else { return nil }
            let sorted = items.sorted(by: sortAssetsForRun)
            let created = sorted.map(\.metadata.createdAt).min() ?? first.metadata.createdAt
            let latest = sorted.map(\.metadata.createdAt).max() ?? first.metadata.createdAt
            let operation = first.metadata.operation
                ?? (first.metadata.parentImageID != nil || !first.metadata.referenceIDs.isEmpty ? .reference : .generate)
            return IterationRun(
                id: runID,
                projectID: first.metadata.projectID,
                prompt: first.metadata.prompt,
                createdAt: created,
                latestAt: latest,
                parentImageID: first.metadata.parentImageID,
                referenceIDs: first.metadata.referenceIDs,
                operation: operation,
                assets: sorted
            )
        }
        .sorted {
            if $0.latestAt == $1.latestAt { return $0.id < $1.id }
            return $0.latestAt > $1.latestAt
        }
    }

    private static func sortAssetsForRun(_ lhs: ImageAsset, _ rhs: ImageAsset) -> Bool {
        let leftIndex = lhs.metadata.variantIndex ?? Int.max
        let rightIndex = rhs.metadata.variantIndex ?? Int.max
        if leftIndex != rightIndex { return leftIndex < rightIndex }
        if lhs.metadata.createdAt != rhs.metadata.createdAt {
            return lhs.metadata.createdAt < rhs.metadata.createdAt
        }
        return lhs.id < rhs.id
    }
}
