import CryptoKit
import Foundation

/// Verifies Balances license tokens: PASETO v4.public tokens (Ed25519-signed) issued offline by
/// "Bluepill License Gen". The app embeds only the issuer's *public* key and never contacts a
/// server -- verification is entirely local.
///
/// This is a minimal, hand-rolled PASETO v4.public verifier (Ed25519 signature over the
/// "Pre-Authentication Encoding" of the token pieces, per the PASETO spec), built on CryptoKit
/// rather than a third-party PASETO library.
enum LicenseVerifier {
    /// Ed25519 public key for "Bluepill License Gen" (hex-encoded, 32 bytes).
    static let issuerPublicKeyHex = "378364a9fe971ad713df0b610b5e0e93574febf18fc82753295bb56cbfe16d0b"

    static let expectedIssuer = "Bluepill License Gen"
    static let expectedProduct = "Balances.app"

    private static let tokenHeader = "v4.public."

    /// Claims extracted from a successfully-verified license token.
    struct LicenseInfo: Equatable {
        let name: String
        let email: String
        let product: String
        let seats: Int
        let expiration: Date?
    }

    /// Reasons a token can fail verification, each with a message suitable for display.
    enum LicenseError: Error, Equatable {
        case malformed
        case badSignature
        case expired
        case wrongIssuer
        case wrongProduct
        case badKey

        var userMessage: String {
            switch self {
            case .malformed:
                return "That doesn't look like a valid license key."
            case .badSignature:
                return "This license's signature couldn't be verified."
            case .expired:
                return "This license has expired."
            case .wrongIssuer:
                return "This license wasn't issued for Balances."
            case .wrongProduct:
                return "This license is for a different product."
            case .badKey:
                return "The app's embedded license key is invalid. Please reinstall Balances."
            }
        }
    }

    /// ISO-8601 (with seconds, UTC "Z") formatter for the `iat`/`exp` claims, e.g.
    /// "2027-06-11T21:45:31Z".
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Verifies `rawToken` against the embedded public key, the expected issuer, and an
    /// expiration (if present). On success, also checks the `product` claim. Never throws --
    /// all failures are reported via `LicenseError`.
    static func verify(token rawToken: String) -> Result<LicenseInfo, LicenseError> {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return .failure(.malformed) }

        guard let publicKeyData = Data(hexString: issuerPublicKeyHex),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        else {
            return .failure(.badKey)
        }

        guard token.hasPrefix(tokenHeader) else { return .failure(.malformed) }
        let rest = token.dropFirst(tokenHeader.count)

        // PASETO tokens may optionally carry a base64url-encoded footer after a final ".".
        let segments = rest.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard segments.count == 1 || segments.count == 2 else { return .failure(.malformed) }
        let payloadSegment = segments[0]
        let footer: Data
        if segments.count == 2 {
            guard let footerData = Data(base64URLEncoded: String(segments[1])) else {
                return .failure(.malformed)
            }
            footer = footerData
        } else {
            footer = Data()
        }

        guard let payload = Data(base64URLEncoded: String(payloadSegment)),
              payload.count > 64
        else {
            return .failure(.malformed)
        }

        let signature = payload.suffix(64)
        let message = payload.prefix(payload.count - 64)

        let signedMessage = pae([Data(tokenHeader.utf8), Data(message), footer, Data()])
        guard publicKey.isValidSignature(signature, for: signedMessage) else {
            return .failure(.badSignature)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: Data(message)),
            let claims = json as? [String: Any]
        else {
            return .failure(.malformed)
        }

        guard let issuer = claims["iss"] as? String, issuer == expectedIssuer else {
            return .failure(.wrongIssuer)
        }

        var expiration: Date?
        if let expString = claims["exp"] as? String {
            guard let exp = dateFormatter.date(from: expString) else { return .failure(.malformed) }
            guard Date() < exp else { return .failure(.expired) }
            expiration = exp
        }

        guard let product = claims["product"] as? String, product == expectedProduct else {
            return .failure(.wrongProduct)
        }

        let seatsString = claims["seats"] as? String
        return .success(LicenseInfo(
            name: claims["name"] as? String ?? "",
            email: claims["email"] as? String ?? "",
            product: product,
            seats: seatsString.flatMap(Int.init) ?? 1,
            expiration: expiration
        ))
    }

    /// PASETO's "Pre-Authentication Encoding": a length-prefixed concatenation, used to bind the
    /// header/footer/implicit-assertion into the signed message alongside the payload.
    private static func pae(_ pieces: [Data]) -> Data {
        var out = le64(pieces.count)
        for piece in pieces {
            out += le64(piece.count)
            out += piece
        }
        return out
    }

    /// 8-byte little-endian encoding with the most-significant bit cleared, per the PASETO spec.
    private static func le64(_ n: Int) -> Data {
        var value = UInt64(n) & 0x7FFF_FFFF_FFFF_FFFF
        var bytes = [UInt8]()
        bytes.reserveCapacity(8)
        for _ in 0..<8 {
            bytes.append(UInt8(value & 0xFF))
            value >>= 8
        }
        return Data(bytes)
    }
}

private extension Data {
    /// Decodes a hex string (e.g. a 32-byte Ed25519 public key) into raw bytes.
    init?(hexString: String) {
        let chars = Array(hexString)
        guard chars.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let byte = UInt8(String(chars[i...i+1]), radix: 16) else { return nil }
            bytes.append(byte)
            i += 2
        }
        self = Data(bytes)
    }

    /// Decodes unpadded base64url (the encoding PASETO uses for its payload and footer).
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        self = data
    }
}
