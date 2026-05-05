import Foundation

struct IterationThreadGroup: Identifiable, Hashable, Sendable {
    let id: String
    let parentImageID: String?
    let runs: [IterationRun]

    var projectID: String { runs.first?.projectID ?? "" }
    var operation: ImageOperation { runs.first?.operation ?? .generate }
    var latestAt: Date { runs.map(\.latestAt).max() ?? Date.distantPast }
    var createdAt: Date { runs.map(\.createdAt).min() ?? Date.distantPast }

    var assets: [ImageAsset] {
        runs.flatMap(\.assets).sorted {
            if $0.metadata.createdAt != $1.metadata.createdAt {
                return $0.metadata.createdAt < $1.metadata.createdAt
            }
            let leftIndex = $0.metadata.variantIndex ?? Int.max
            let rightIndex = $1.metadata.variantIndex ?? Int.max
            if leftIndex != rightIndex { return leftIndex < rightIndex }
            return $0.id < $1.id
        }
    }

    static func group(_ runs: [IterationRun]) -> [IterationThreadGroup] {
        var order: [String] = []
        var buckets: [String: [IterationRun]] = [:]
        var parentByKey: [String: String] = [:]

        for run in runs {
            let key = run.parentImageID ?? "run:\(run.id)"
            if buckets[key] == nil {
                order.append(key)
                if let parentID = run.parentImageID {
                    parentByKey[key] = parentID
                }
            }
            buckets[key, default: []].append(run)
        }

        return order.compactMap { key in
            guard let items = buckets[key] else { return nil }
            return IterationThreadGroup(
                id: key,
                parentImageID: parentByKey[key],
                runs: items
            )
        }
    }

    static func lineages(_ runs: [IterationRun]) -> [IterationThreadGroup] {
        let runsByID = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        let runIDByAssetID = Dictionary(
            uniqueKeysWithValues: runs.flatMap { run in
                run.assets.map { ($0.id, run.id) }
            }
        )
        var rootCache: [String: String] = [:]

        func rootID(for run: IterationRun) -> String {
            if let cached = rootCache[run.id] { return cached }

            var cursor = run
            var visited: Set<String> = [run.id]
            while let parentImageID = cursor.parentImageID,
                  let parentRunID = runIDByAssetID[parentImageID],
                  let parentRun = runsByID[parentRunID],
                  !visited.contains(parentRunID) {
                cursor = parentRun
                visited.insert(parentRunID)
            }

            rootCache[run.id] = cursor.id
            return cursor.id
        }

        var order: [String] = []
        var buckets: [String: [IterationRun]] = [:]

        for run in runs {
            let root = rootID(for: run)
            if buckets[root] == nil {
                order.append(root)
            }
            buckets[root, default: []].append(run)
        }

        return order.compactMap { root in
            guard let items = buckets[root] else { return nil }
            return IterationThreadGroup(
                id: "lineage:\(root)",
                parentImageID: nil,
                runs: items.sorted {
                    if $0.createdAt == $1.createdAt { return $0.id < $1.id }
                    return $0.createdAt < $1.createdAt
                }
            )
        }
        .sorted {
            if $0.latestAt == $1.latestAt { return $0.id < $1.id }
            return $0.latestAt > $1.latestAt
        }
    }

    func filteringAssets(_ isIncluded: (ImageAsset) -> Bool) -> IterationThreadGroup? {
        let filteredRuns = runs.compactMap { run -> IterationRun? in
            let kept = run.assets.filter(isIncluded)
            guard !kept.isEmpty else { return nil }
            let created = kept.map(\.metadata.createdAt).min() ?? run.createdAt
            let latest = kept.map(\.metadata.createdAt).max() ?? run.latestAt
            return IterationRun(
                id: run.id,
                projectID: run.projectID,
                prompt: run.prompt,
                createdAt: created,
                latestAt: latest,
                parentImageID: run.parentImageID,
                referenceIDs: run.referenceIDs,
                operation: run.operation,
                assets: kept
            )
        }
        guard !filteredRuns.isEmpty else { return nil }
        return IterationThreadGroup(
            id: id,
            parentImageID: parentImageID,
            runs: filteredRuns
        )
    }
}
