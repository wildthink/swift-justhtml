// DoSProtectionTests.swift - Tests for DoS attack prevention
//
// These tests verify that the parser handles pathological inputs gracefully
// without crashing or consuming excessive resources. The limits are set high
// enough that no real-world HTML document should ever hit them.
//
// Current findings:
// - Entity names: 100K chars takes ~0.7s, 1M chars takes ~68s (needs limit)
// - Nesting depth: 5000 mixed tags OK (~11s), 10000 divs crashes (SIGSEGV)
//
// Recommended limits:
// - Entity name: 64 characters (longest valid is ~31)
// - Nesting depth: 512 levels (real pages rarely exceed 100)

import Foundation
import Testing

@testable import justhtml

// MARK: - Entity Name Length DoS Tests

/// Tests for entity name length limits
/// The longest valid HTML entity is ~31 characters (e.g., "CounterClockwiseContourIntegral")
/// We set a limit of 64 characters which no valid entity will ever reach
@Suite("Entity Name Length DoS Protection")
struct EntityNameLengthTests {
	/// Test that valid entities still work with limits in place
	@Test func testValidEntitiesStillWork() throws {
		let html = "&amp; &lt; &gt; &quot; &nbsp; &copy; &mdash;"
		let doc = try JustHTML(html)
		let text = doc.toText()

		#expect(text.contains("&"))
		#expect(text.contains("<"))
		#expect(text.contains(">"))
	}

	/// Test the longest valid HTML entity
	@Test func testLongestValidEntity() throws {
		// CounterClockwiseContourIntegral is one of the longest at 31 chars
		let html = "&CounterClockwiseContourIntegral;"
		let doc = try JustHTML(html)
		let text = doc.toText()
		#expect(text.contains("∳")) // The actual character
	}

	/// Test entity name at 64 characters (at the proposed limit)
	@Test func testEntityNameAtBoundary() throws {
		let name64 = String(repeating: "d", count: 64)
		let html = "&\(name64);"

		let doc = try JustHTML(html)
		_ = doc.toHTML()
	}

	/// Test that long entity names complete quickly (with limit in place)
	/// Without a limit, 100K chars takes ~0.7s. With limit, should be instant.
	@Test func testLongEntityNamePerformance() throws {
		let longEntityName = String(repeating: "a", count: 100_000)
		let html = "<div>&\(longEntityName);</div>"

		let start = Date()
		let doc = try JustHTML(html)
		let output = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		// With a 64-char limit, this should complete in under 0.1s
		// The invalid entity should be preserved as literal text
		#expect(output.contains("&"))
		#expect(elapsed < 0.5, "Long entity name should be handled quickly with limit, took \(elapsed)s")
	}

	/// Test multiple long entity names complete quickly
	@Test func testMultipleLongEntityNamesPerformance() throws {
		let longName = String(repeating: "b", count: 50_000)
		let html = "&\(longName); &\(longName); &\(longName);"

		let start = Date()
		let doc = try JustHTML(html)
		_ = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		#expect(elapsed < 1.0, "Multiple long entities should complete quickly, took \(elapsed)s")
	}

	/// Test long entity name in attribute value completes quickly
	@Test func testLongEntityNameInAttributePerformance() throws {
		let longName = String(repeating: "c", count: 100_000)
		let html = "<div title=\"&\(longName);\">text</div>"

		let start = Date()
		let doc = try JustHTML(html)
		_ = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		#expect(elapsed < 0.5, "Long entity in attribute should complete quickly, took \(elapsed)s")
	}

	/// Test numeric character reference with many digits
	/// The numeric value overflows quickly, so this should be fast regardless
	@Test func testLongNumericCharRef() throws {
		let longNumber = String(repeating: "9", count: 1_000)
		let html = "&#\(longNumber);"

		let start = Date()
		let doc = try JustHTML(html)
		_ = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		#expect(elapsed < 0.1, "Long numeric ref should complete quickly, took \(elapsed)s")
	}

	/// Test hex character reference with many digits
	@Test func testLongHexCharRef() throws {
		let longHex = String(repeating: "F", count: 1_000)
		let html = "&#x\(longHex);"

		let start = Date()
		let doc = try JustHTML(html)
		_ = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		#expect(elapsed < 0.1, "Long hex ref should complete quickly, took \(elapsed)s")
	}
}

// MARK: - Nesting Depth DoS Tests

/// Tests for maximum nesting depth limits
/// Real web pages rarely exceed 100-200 levels of nesting
/// We set a limit of 512 levels which no real page should hit
///
/// Current behavior without limits:
/// - 5000 mixed tags: OK (~11s)
/// - 10000 divs: CRASHES (SIGSEGV - stack overflow)
@Suite("Nesting Depth DoS Protection")
struct NestingDepthTests {
	/// Test that reasonable nesting depths work correctly
	@Test func testReasonableNestingWorks() throws {
		// 100 levels is deep but reasonable for real pages
		let depth = 100
		let opens = String(repeating: "<div>", count: depth)
		let closes = String(repeating: "</div>", count: depth)
		let html = opens + "content" + closes

		let doc = try JustHTML(html)
		let output = doc.toHTML()

		// Verify structure is preserved
		#expect(output.contains("content"))
		#expect(output.contains("<div>"))
	}

	/// Test 512 levels (proposed limit) works
	@Test func testNestingAtProposedLimit() throws {
		let depth = 512
		let opens = String(repeating: "<div>", count: depth)
		let closes = String(repeating: "</div>", count: depth)
		let html = opens + "content" + closes

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("content"))
	}

	/// Test deep nesting with mixed tags (within safe limits)
	@Test func testDeepNestingMixedTags() throws {
		let tags = ["div", "span", "section", "article", "main", "aside", "nav", "header"]
		var html = ""
		let depth = 400 // Safe depth

		for i in 0..<depth {
			let tag = tags[i % tags.count]
			html += "<\(tag)>"
		}
		html += "deep content"
		for i in (0..<depth).reversed() {
			let tag = tags[i % tags.count]
			html += "</\(tag)>"
		}

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("deep content"))
	}

	/// Test deep nesting with tables (complex tree construction)
	@Test func testDeepTableNesting() throws {
		let depth = 200 // Tables are more complex
		var html = ""

		for _ in 0..<depth {
			html += "<table><tr><td>"
		}
		html += "cell"
		for _ in 0..<depth {
			html += "</td></tr></table>"
		}

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("cell"))
	}

	/// Test deep nesting with templates
	@Test func testDeepTemplateNesting() throws {
		let depth = 200
		let opens = String(repeating: "<template>", count: depth)
		let closes = String(repeating: "</template>", count: depth)
		let html = opens + "template content" + closes

		let doc = try JustHTML(html)
		_ = doc.toHTML()
	}

	/// Test deep nesting with formatting elements (adoption agency stress)
	@Test func testDeepFormattingNesting() throws {
		let depth = 300
		let opens = String(repeating: "<b><i><u>", count: depth)
		// Don't close them - forces adoption agency algorithm
		let html = opens + "formatted text"

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("formatted text"))
	}

	/// Test deep nesting in fragment context
	@Test func testDeepNestingInFragment() throws {
		let depth = 400
		let opens = String(repeating: "<div>", count: depth)
		let closes = String(repeating: "</div>", count: depth)
		let html = opens + "content" + closes

		let doc = try JustHTML(html, fragmentContext: FragmentContext("div"))
		let output = doc.toHTML()
		#expect(output.contains("content"))
	}

	/// Test deep SVG nesting
	@Test func testDeepSVGNesting() throws {
		let depth = 300
		var html = "<svg>"
		for _ in 0..<depth {
			html += "<g>"
		}
		html += "<text>deep</text>"
		for _ in 0..<depth {
			html += "</g>"
		}
		html += "</svg>"

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("deep"))
	}

	/// Test deep MathML nesting
	@Test func testDeepMathMLNesting() throws {
		let depth = 300
		var html = "<math>"
		for _ in 0..<depth {
			html += "<mrow>"
		}
		html += "<mi>x</mi>"
		for _ in 0..<depth {
			html += "</mrow>"
		}
		html += "</math>"

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("x"))
	}

	/// Test that extreme nesting doesn't crash (with limit in place)
	/// Without limits, 10000 divs causes stack overflow
	/// With limits, should gracefully truncate nesting
	@Test func testExtremeNestingDoesNotCrash() throws {
		let depth = 10_000
		let opens = String(repeating: "<div>", count: depth)
		let closes = String(repeating: "</div>", count: depth)
		let html = opens + "content" + closes

		// With a nesting limit, this should complete without crashing
		// The parser may truncate the nesting or flatten some levels
		let doc = try JustHTML(html)
		let output = doc.toHTML()

		// Content should still be preserved
		#expect(output.contains("content"))
	}

	/// Test unclosed tags creating implicit deep nesting
	@Test func testUnclosedTagsDeepNesting() throws {
		// 10,000 unclosed divs - with limits, should not crash
		let html = String(repeating: "<div>", count: 10_000) + "content"

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("content"))
	}

	/// Test performance with deep but safe nesting
	@Test func testNestingPerformance() throws {
		let depth = 500
		let opens = String(repeating: "<div>", count: depth)
		let closes = String(repeating: "</div>", count: depth)
		let html = opens + "content" + closes

		let start = Date()
		let doc = try JustHTML(html)
		_ = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		// 500 levels should complete quickly
		#expect(elapsed < 2.0, "500-level nesting should complete in under 2s, took \(elapsed)s")
	}
}

// MARK: - Adoption Agency DoS Tests

/// Tests for adoption agency algorithm limits
/// The adoption agency is O(n²) in worst case - we need limits
@Suite("Adoption Agency DoS Protection")
struct AdoptionAgencyTests {
	/// Test many overlapping formatting elements (within safe limits)
	@Test func testManyOverlappingFormatting() throws {
		let count = 200
		var html = ""
		for i in 0..<count {
			html += "<b id=\"\(i)\">"
		}
		html += "text"
		// Close in wrong order to trigger adoption agency
		for i in 0..<count {
			html += "</b>"
			if i % 10 == 0 {
				html += "<p>para</p>" // Block elements interspersed
			}
		}

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("text"))
	}

	/// Test adoption agency with nested blocks (within safe limits)
	@Test func testAdoptionAgencyDeepBlocks() throws {
		var html = ""
		for _ in 0..<100 {
			html += "<b><div>"
		}
		html += "content"
		for _ in 0..<100 {
			html += "</b></div>"
		}

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("content"))
	}

	/// Test Noah's Ark clause with many identical elements
	@Test func testNoahsArkManyElements() throws {
		// Noah's Ark clause limits to 3 identical elements
		// Test with more to ensure limit is enforced
		let html = String(repeating: "<b>", count: 200) + "text" + String(repeating: "</b>", count: 200)

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("text"))
	}
}

// MARK: - Active Formatting Elements DoS Tests

/// Tests for active formatting elements list limits
@Suite("Active Formatting Elements DoS Protection")
struct ActiveFormattingTests {
	/// Test many formatting elements without markers (within safe limits)
	@Test func testManyFormattingElements() throws {
		var html = ""
		let tags = ["a", "b", "code", "em", "i", "s", "small", "strong", "u"]

		for i in 0..<200 {
			let tag = tags[i % tags.count]
			html += "<\(tag) class=\"c\(i)\">"
		}
		html += "formatted"

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("formatted"))
	}

	/// Test formatting elements with many markers (table cells)
	@Test func testFormattingWithManyMarkers() throws {
		var html = "<table>"
		for _ in 0..<100 {
			html += "<tr><td><b><i>"
		}
		html += "cell"
		for _ in 0..<100 {
			html += "</i></b></td></tr>"
		}
		html += "</table>"

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("cell"))
	}
}

// MARK: - Combined DoS Tests

/// Tests combining multiple DoS vectors
@Suite("Combined DoS Protection")
struct CombinedDoSTests {
	/// Test deep nesting with long entity names
	/// With limits: long entity aborts quickly, nesting limited
	@Test func testDeepNestingWithLongEntities() throws {
		let longEntity = String(repeating: "e", count: 10_000)
		let depth = 200
		var html = ""

		for _ in 0..<depth {
			html += "<div>&\(longEntity);"
		}
		html += "content"
		for _ in 0..<depth {
			html += "</div>"
		}

		let start = Date()
		let doc = try JustHTML(html)
		let output = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		#expect(output.contains("content"))
		// With entity limit, this should be fast
		#expect(elapsed < 2.0, "Combined test should complete quickly, took \(elapsed)s")
	}

	/// Test moderate stress combination
	@Test func testCombinedStress() throws {
		let longEntity = String(repeating: "f", count: 5_000)
		var html = ""

		// Moderate nesting
		for i in 0..<100 {
			html += "<div class=\"d\(i)\">"
		}

		// Long entity (should abort quickly with limit)
		html += "&\(longEntity);"

		// Some formatting elements
		for _ in 0..<50 {
			html += "<b><i><u>"
		}

		html += "stress test content"

		// Close some formatting
		for _ in 0..<25 {
			html += "</u></i></b>"
		}

		// Close divs
		for _ in 0..<100 {
			html += "</div>"
		}

		let doc = try JustHTML(html)
		let output = doc.toHTML()
		#expect(output.contains("stress test content"))
	}

	/// Test large document with mixed patterns
	@Test func testLargePathologicalDocument() throws {
		var html = "<!DOCTYPE html><html><head><title>Test</title></head><body>"

		// Add various patterns
		for i in 0..<50 {
			// Moderate nesting section
			let opens = String(repeating: "<div>", count: 10)
			let closes = String(repeating: "</div>", count: 10)

			// Long entity (should abort quickly)
			let entity = "&" + String(repeating: "x", count: 500) + ";"

			// Formatting mess
			let formatting = "<b><i><u>text</b></i></u>"

			html += "<section id=\"s\(i)\">\(opens)\(entity)\(formatting)\(closes)</section>"
		}

		html += "</body></html>"

		let start = Date()
		let doc = try JustHTML(html)
		let output = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		#expect(output.contains("text"))
		#expect(elapsed < 5.0, "Large document should complete in reasonable time, took \(elapsed)s")
	}
}

// MARK: - Performance Baseline Tests

/// Tests to establish performance baselines for DoS protection
@Suite("DoS Protection Performance")
struct DoSPerformanceTests {
	/// Verify parsing completes within reasonable time for safe depth
	@Test func testSafeNestingPerformance() throws {
		let depth = 500
		let opens = String(repeating: "<div>", count: depth)
		let closes = String(repeating: "</div>", count: depth)
		let html = opens + "content" + closes

		let start = Date()
		let doc = try JustHTML(html)
		_ = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		#expect(elapsed < 2.0, "500-level nesting should complete quickly, took \(elapsed)s")
	}

	/// Verify long entity names complete quickly with limit
	@Test func testLongEntityPerformance() throws {
		let longEntity = String(repeating: "a", count: 100_000)
		let html = "&\(longEntity);"

		let start = Date()
		let doc = try JustHTML(html)
		_ = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		// With a 64-char limit, should complete almost instantly
		#expect(elapsed < 0.5, "Long entity should complete quickly with limit, took \(elapsed)s")
	}

	/// Test that extreme nesting is handled (with limits)
	@Test func testExtremeNestingWithLimits() throws {
		let depth = 10_000
		let opens = String(repeating: "<div>", count: depth)
		let closes = String(repeating: "</div>", count: depth)
		let html = opens + "content" + closes

		// With nesting limit, this should not crash
		let start = Date()
		let doc = try JustHTML(html)
		let output = doc.toHTML()
		let elapsed = Date().timeIntervalSince(start)

		#expect(output.contains("content"))
		#expect(elapsed < 10.0, "Extreme nesting with limits should complete, took \(elapsed)s")
	}
}
