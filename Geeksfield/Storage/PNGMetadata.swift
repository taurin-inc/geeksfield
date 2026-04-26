import Foundation

enum PNGMetadataError: Error {
    case notAPNG
    case writeFailed
}

/// PNG tEXt chunk reader/writer. We embed `geeksfield.id` so an image can always
/// be matched back to its metadata json even if renamed outside the app.
enum PNGMetadata {
    private static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    static func readTextEntries(from data: Data) throws -> [String: String] {
        try validateSignature(data)
        var offset = 8
        var result: [String: String] = [:]
        while offset + 8 <= data.count {
            let length = Int(readUInt32(data, at: offset))
            offset += 4
            guard offset + 4 + length + 4 <= data.count else { break }
            let type = data.subdata(in: offset..<offset + 4)
            offset += 4
            let payload = data.subdata(in: offset..<offset + length)
            offset += length
            offset += 4 // crc

            guard let typeStr = String(data: type, encoding: .ascii) else { continue }
            if typeStr == "IEND" { break }
            if typeStr == "tEXt", let sep = payload.firstIndex(of: 0x00) {
                let key = String(data: payload.subdata(in: 0..<sep), encoding: .isoLatin1) ?? ""
                let value = String(data: payload.subdata(in: sep + 1..<payload.count), encoding: .isoLatin1) ?? ""
                result[key] = value
            }
        }
        return result
    }

    static func write(textEntries: [String: String], into data: Data) throws -> Data {
        try validateSignature(data)
        var chunks = Data()
        chunks.append(data.subdata(in: 0..<8))

        var offset = 8
        var textInserted = false

        while offset + 8 <= data.count {
            let length = Int(readUInt32(data, at: offset))
            let chunkEnd = offset + 4 + 4 + length + 4
            guard chunkEnd <= data.count else { break }
            let type = data.subdata(in: offset + 4..<offset + 8)
            let typeStr = String(data: type, encoding: .ascii) ?? ""

            // tEXt chunks must come after IHDR and before IDAT. Inject on first IDAT.
            if typeStr == "IDAT" && !textInserted {
                for (k, v) in textEntries {
                    chunks.append(makeTextChunk(keyword: k, value: v))
                }
                textInserted = true
            }

            chunks.append(data.subdata(in: offset..<chunkEnd))
            offset = chunkEnd
            if typeStr == "IEND" { break }
        }

        if !textInserted {
            throw PNGMetadataError.writeFailed
        }
        return chunks
    }

    // MARK: - Helpers

    private static func validateSignature(_ data: Data) throws {
        guard data.count >= 8,
              Array(data.prefix(8)) == signature else {
            throw PNGMetadataError.notAPNG
        }
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let b = data.subdata(in: offset..<offset + 4)
        return UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3])
    }

    private static func makeTextChunk(keyword: String, value: String) -> Data {
        var payload = Data()
        payload.append(keyword.data(using: .isoLatin1) ?? Data())
        payload.append(0x00)
        payload.append(value.data(using: .isoLatin1) ?? Data())

        var chunk = Data()
        chunk.append(uint32BE(UInt32(payload.count)))
        let type = "tEXt".data(using: .ascii)!
        chunk.append(type)
        chunk.append(payload)
        let crc = crc32(type + payload)
        chunk.append(uint32BE(crc))
        return chunk
    }

    private static func uint32BE(_ v: UInt32) -> Data {
        var data = Data(count: 4)
        data[0] = UInt8((v >> 24) & 0xFF)
        data[1] = UInt8((v >> 16) & 0xFF)
        data[2] = UInt8((v >> 8) & 0xFF)
        data[3] = UInt8(v & 0xFF)
        return data
    }

    // CRC32 with PNG polynomial. Computed once, cached.
    private static let crcTable: [UInt32] = {
        (0...255).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in data {
            c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8)
        }
        return c ^ 0xFFFFFFFF
    }
}
