import Foundation

/// Keccak-256（Ethereum `keccak256`，非 NIST SHA3-256）
enum Keccak256 {
    static func hash(_ input: [UInt8]) -> [UInt8] {
        var state = [UInt64](repeating: 0, count: 25)
        var data = input
        data.append(0x01)
        while (data.count % 136) != 135 {
            data.append(0x00)
        }
        data[data.count - 1] |= 0x80

        var offset = 0
        while offset < data.count {
            for i in 0..<17 {
                let start = i * 8
                var lane: UInt64 = 0
                for j in 0..<8 where offset + start + j < data.count {
                    lane |= UInt64(data[offset + start + j]) << (8 * j)
                }
                state[i] ^= lane
            }
            keccakF(&state)
            offset += 136
        }

        var out = [UInt8]()
        out.reserveCapacity(32)
        while out.count < 32 {
            for i in 0..<17 where out.count < 32 {
                var lane = state[i]
                for _ in 0..<8 where out.count < 32 {
                    out.append(UInt8(lane & 0xff))
                    lane >>= 8
                }
            }
            if out.count < 32 { keccakF(&state) }
        }
        return Array(out.prefix(32))
    }

    private static let roundConstants: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000,
        0x000000000000808b, 0x0000000080000001, 0x8000000080008008, 0x800000000000800a,
        0x800000008000000a, 0x8000000080008081, 0x8000000000008000, 0x0000000080000001,
        0x8000000080008008, 0x000000000000808b, 0x800000000000808a, 0x8000000080008080,
        0x0000000080000001, 0x8000000080008008, 0x800000000000800a, 0x8000000080008081,
        0x8000000000008080, 0x0000000080000001, 0x8000000080008008, 0x800000000000800a,
    ]

    private static let rhoOffsets = [
        0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2,
        61, 56, 14,
    ]

    private static func keccakF(_ state: inout [UInt64]) {
        for round in 0..<24 {
            var c = [UInt64](repeating: 0, count: 5)
            for x in 0..<5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }
            var d = [UInt64](repeating: 0, count: 5)
            for x in 0..<5 {
                d[x] = c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1)
            }
            for x in 0..<5 {
                for y in 0..<5 {
                    state[x + 5 * y] ^= d[x]
                }
            }

            var b = [UInt64](repeating: 0, count: 25)
            for x in 0..<5 {
                for y in 0..<5 {
                    let index = x + 5 * y
                    b[y + 5 * ((2 * x + 3 * y) % 5)] = rotl(state[index], rhoOffsets[index])
                }
            }

            for x in 0..<5 {
                for y in 0..<5 {
                    let i = x + 5 * y
                    state[i] = b[i] ^ ((~b[((x + 1) % 5) + 5 * y]) & b[((x + 2) % 5) + 5 * y])
                }
            }
            state[0] ^= roundConstants[round]
        }
    }

    private static func rotl(_ value: UInt64, _ shift: Int) -> UInt64 {
        (value << shift) | (value >> (64 - shift))
    }
}
