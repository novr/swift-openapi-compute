[![Build](https://github.com/novr/swift-openapi-compute/actions/workflows/swift.yml/badge.svg)](https://github.com/novr/swift-openapi-compute/actions/workflows/swift.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnovr%2Fswift-openapi-compute%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/novr/swift-openapi-compute)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fnovr%2Fswift-openapi-compute%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/novr/swift-openapi-compute)

# Swift OpenAPI Compute

This package provides Compute Bindings for the [OpenAPI generator](https://github.com/apple/swift-openapi-generator).

## Usage

In `entrypoint.swift` add:

```swift
// Create a Compute OpenAPI Transport using your router.
let transport = ComputeTransport(router)

// Create an instance of your handler type that conforms the generated protocol
// defining your service API.
let handler = MyServiceAPIImpl()

// Call the generated function on your implementation to add its request
// handlers to the app.
try handler.registerHandlers(on: transport, serverURL: Servers.server1())
```

## Documentation

TBD
