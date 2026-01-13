// ParserLimits.swift - Configurable limits for DoS protection
//
// These limits prevent pathological inputs from causing crashes or
// excessive resource consumption. The defaults are set high enough
// that no real-world HTML document should ever hit them.

import Foundation

/// Configurable limits for the HTML parser
///
/// These limits protect against denial-of-service attacks from malicious
/// or pathological HTML input. The default values are conservative and
/// should never be reached by legitimate web content.
///
/// Example usage:
/// ```swift
/// // Use default limits (recommended for most use cases)
/// let doc = try JustHTML(html)
///
/// // Use larger limits for server with lots of RAM
/// var limits = ParserLimits()
/// limits.maxNestingDepth = 2048
/// let doc = try JustHTML(html, limits: limits)
///
/// // Disable limits entirely (not recommended)
/// let doc = try JustHTML(html, limits: .unlimited)
/// ```
public struct ParserLimits: Sendable {
	/// Maximum length for named character reference entity names.
	///
	/// The longest valid HTML entity is ~31 characters (e.g., "CounterClockwiseContourIntegral").
	/// Setting this limit prevents the tokenizer from allocating huge strings when
	/// parsing malicious input like `&aaaa...` with millions of characters.
	///
	/// Default: 255 characters
	public var maxEntityNameLength: Int

	/// Maximum depth of nested elements in the DOM tree.
	///
	/// Real web pages rarely exceed 100-200 levels of nesting. Extremely deep
	/// nesting (10,000+ levels) can cause stack overflow crashes during tree
	/// construction or serialization.
	///
	/// When this limit is reached, additional elements are inserted as siblings
	/// rather than children, preserving the content while flattening the structure.
	///
	/// Default: 512 levels
	public var maxNestingDepth: Int

	/// Create parser limits with default values.
	///
	/// Default limits:
	/// - `maxEntityNameLength`: 255 characters
	/// - `maxNestingDepth`: 512 levels
	public init(
		maxEntityNameLength: Int = 255,
		maxNestingDepth: Int = 512
	) {
		self.maxEntityNameLength = maxEntityNameLength
		self.maxNestingDepth = maxNestingDepth
	}

	/// Default limits suitable for most applications.
	///
	/// These limits are conservative and should never be reached by
	/// legitimate web content.
	public static let `default` = ParserLimits()

	/// Unlimited parsing (no DoS protection).
	///
	/// **Warning:** Using unlimited parsing on untrusted input may cause
	/// crashes or excessive memory/CPU usage. Only use this when parsing
	/// trusted content or when you have other safeguards in place.
	public static let unlimited = ParserLimits(
		maxEntityNameLength: Int.max,
		maxNestingDepth: Int.max
	)

	/// Strict limits for resource-constrained environments (e.g., mobile devices).
	///
	/// These limits are more restrictive but should still handle all
	/// well-formed web content.
	public static let strict = ParserLimits(
		maxEntityNameLength: 128,
		maxNestingDepth: 256
	)
}
