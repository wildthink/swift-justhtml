# DoS Protection

Configure parser limits to protect against denial-of-service attacks from malicious HTML input.

## Overview

swift-justhtml includes configurable limits to prevent pathological HTML input from causing crashes or excessive resource consumption. These limits are designed to be high enough that no legitimate web content will ever trigger them, while protecting against malicious input.

The ``ParserLimits`` struct controls two key limits:

- **Entity Name Length**: Prevents memory allocation attacks from extremely long invalid entity names (e.g., `&aaaa...` with millions of characters)
- **Nesting Depth**: Prevents stack overflow from extremely deep DOM nesting (e.g., 10,000+ nested `<div>` elements)

## Default Behavior

By default, swift-justhtml uses sensible limits that protect against attacks while handling all legitimate web content:

```swift
import justhtml

// Default limits are applied automatically
let doc = try JustHTML(untrustedHTML)
```

The default limits are:
- `maxEntityNameLength`: 255 characters (longest valid entity is ~31 chars)
- `maxNestingDepth`: 512 levels (real pages rarely exceed 100-200)

## Configuring Limits

You can customize limits for specific use cases:

### Server with Large RAM

If you're processing very large documents on a server with ample resources:

```swift
var limits = ParserLimits()
limits.maxNestingDepth = 2048  // Allow deeper nesting

let doc = try JustHTML(html, limits: limits)
```

### Resource-Constrained Devices

For mobile devices or embedded systems, use stricter limits:

```swift
let doc = try JustHTML(html, limits: .strict)
```

The `.strict` preset uses:
- `maxEntityNameLength`: 128 characters
- `maxNestingDepth`: 256 levels

### Trusted Content

If you're parsing trusted content (e.g., your own templates), you can disable limits entirely:

```swift
let doc = try JustHTML(trustedHTML, limits: .unlimited)
```

> Warning: Only use `.unlimited` with trusted input. Malicious HTML could cause crashes or excessive resource usage.

## How Limits Work

### Entity Name Limit

When the tokenizer encounters an entity like `&name;`, it collects alphanumeric characters to identify the entity. If the name exceeds the limit:

1. The tokenizer stops looking for entity matches
2. The full text is preserved in the output (including characters beyond the limit)
3. Processing continues normally

This means malicious input like `&aaaa...` (with millions of 'a's) completes quickly instead of building a huge string.

### Nesting Depth Limit

When the tree builder would push an element onto the open elements stack:

1. If the stack is at the limit, the element is still added to the DOM
2. But it's not pushed onto the stack, so it becomes effectively void
3. Subsequent content is inserted into the parent element instead

This prevents stack overflow while preserving all content. The DOM structure may be flattened at extreme depths, but no content is lost.

## Presets Reference

| Preset | Entity Length | Nesting Depth | Use Case |
|--------|--------------|---------------|----------|
| `.default` | 255 | 512 | General use |
| `.strict` | 128 | 256 | Mobile/embedded |
| `.unlimited` | unlimited | unlimited | Trusted content only |

## Topics

### Configuration

- ``ParserLimits``
