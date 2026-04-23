// AssetLoader.swift — loads bundled JSON starter packs and MIDI assets from Resources/
// Copyright (c) 2026 Zack Urlocker

import Foundation

struct AssetLoader {
    // MARK: - Bundle access

    private static var resourceURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Resources")
    }

    // MARK: - Starter JSON loading

    /// Loads a named JSON asset from Resources/ and decodes it as T.
    static func load<T: Decodable>(_ filename: String, as type: T.Type = T.self) throws -> T {
        guard let base = resourceURL else {
            throw AssetError.resourceURLNotFound
        }
        let url = base.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Returns URLs for all files in the given subdirectory of Resources/.
    static func urls(inDirectory directory: String) -> [URL] {
        guard let base = resourceURL else { return [] }
        let dir = base.appendingPathComponent(directory)
        return (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )) ?? []
    }

    // MARK: - Error

    enum AssetError: Error {
        case resourceURLNotFound
        case fileNotFound(String)
    }
}
