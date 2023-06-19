import Foundation
import OpenAPIRuntime
import Compute

public final class ComputeTransport {
    internal var router: Compute.Router

    public init(router: Compute.Router) {
        self.router = router
    }
}

extension ComputeTransport: ServerTransport {
    public func register(
        _ handler: @escaping @Sendable (OpenAPIRuntime.Request, OpenAPIRuntime.ServerRequestMetadata) async throws -> OpenAPIRuntime.Response,
        method: OpenAPIRuntime.HTTPMethod,
        path: [OpenAPIRuntime.RouterPathComponent],
        queryItemNames: Set<String>) throws {
            router.on(
                try Compute.HTTPMethod(method),
                Self.makeComputePath(from: path)
            ) { computeRequest in
                let request = try await OpenAPIRuntime.Request(computeRequest)
                let requestMetadata = try OpenAPIRuntime.ServerRequestMetadata(
                    from: computeRequest,
                    forPath: path,
                    extractingQueryItemNamed: queryItemNames
                )
                return try await handler(request, requestMetadata)
            }
        }

    /// Make compute path string from RouterPathComponent array
    static func makeComputePath(from path: [OpenAPIRuntime.RouterPathComponent]) -> String {
        path.map(\.computePathComponent).joined(separator: "/")
    }
}

extension RouterPathComponent {
    /// Return path component as String
    var computePathComponent: String {
        switch self {
        case .constant(let string):
            return string
        case .parameter(let parameter):
            return ":\(parameter)"
        }
    }
}

extension Compute.Router {

    @discardableResult
    func on(
        _ method: Compute.HTTPMethod,
        _ path: String,
        use closure: @escaping (IncomingRequest) async throws -> OpenAPIRuntime.Response
    ) -> Compute.Router {
        let handler: (IncomingRequest, OutgoingResponse) async throws -> Void =  { request, response in
            let result = try await closure(request)
            response.status(result.statusCode)
            for header in result.headerFields {
                response.header(header.name, header.value)
            }
            try await response.send(result.body)
        }
        switch method {
        case .get:
            return self.get(path, handler)

        case .head:
            return self.head(path, handler)

        case .delete:
            return self.delete(path, handler)

        case .options:
            return self.options(path, handler)

        case .patch:
            return self.patch(path, handler)

        case .post:
            return self.post(path, handler)

        case .put:
            return self.put(path, handler)

        default:
            return self
        }
    }
}

enum ComputeTransportError: Error {
    case unsupportedHTTPMethod(String)
    case duplicatePathParameter([String])
    case missingRequiredPathParameter(String)
}

extension Compute.PathComponent {
    init(_ pathComponent: OpenAPIRuntime.RouterPathComponent) {
        switch pathComponent {
        case .constant(let value): self = .constant(value)
        case .parameter(let value): self = .parameter(value)
        }
    }
}

extension OpenAPIRuntime.Request {
    init(_ computeRequest: Compute.IncomingRequest) async throws {
        let headerFields: [OpenAPIRuntime.HeaderField] = .init(computeRequest.headers)
        let bodyData = try await computeRequest.body.data()
        let method = try OpenAPIRuntime.HTTPMethod(computeRequest.method)

        self.init(
            path: computeRequest.url.path,
            query: computeRequest.url.query,
            method: method,
            headerFields: headerFields,
            body: bodyData
        )
    }
}

extension OpenAPIRuntime.ServerRequestMetadata {
    init(
        from computeRequest: Compute.IncomingRequest,
        forPath path: [RouterPathComponent],
        extractingQueryItemNamed queryItemNames: Set<String>
    ) throws {
        self.init(
            pathParameters: try .init(from: computeRequest, forPath: path),
            queryParameters: .init(from: computeRequest, queryItemNames: queryItemNames)
        )
    }
}

extension Dictionary where Key == String, Value == String {
    init(from computeRequest: Compute.IncomingRequest, forPath path: [RouterPathComponent]) throws {
        let keysAndValues = try path.compactMap { item -> (String, String)? in
            guard case let .parameter(name) = item else {
                return nil
            }
            guard let value = computeRequest.pathParams.get(name) else {
                throw ComputeTransportError.missingRequiredPathParameter(name)
            }
            return (name, value)
        }
        let pathParameterDictionary = try Dictionary(keysAndValues, uniquingKeysWith: { _, _ in
            throw ComputeTransportError.duplicatePathParameter(keysAndValues.map(\.0))
        })
        self = pathParameterDictionary
    }
}

extension Array where Element == URLQueryItem {
    init(from computeRequest: Compute.IncomingRequest, queryItemNames: Set<String>) {
        let queryParameters = queryItemNames.sorted().compactMap { name -> URLQueryItem? in
            guard let value = computeRequest.searchParams[name] else {
                return nil
            }
            return .init(name: name, value: value)
        }
        self = queryParameters
    }
}

extension Array where Element == OpenAPIRuntime.HeaderField {
    init(_ headers: Compute.Headers) {
        self = headers.entries().map { .init(name: $0.key, value: $0.value) }
    }
}

extension OpenAPIRuntime.HTTPMethod {
    init(_ method: Compute.HTTPMethod) throws {
        switch method {
        case .get: self = .get
        case .put: self = .put
        case .post: self = .post
        case .delete: self = .delete
        case .options: self = .options
        case .head: self = .head
        case .patch: self = .patch
        default: throw ComputeTransportError.unsupportedHTTPMethod(method.rawValue)
        }
    }
}

extension Compute.HTTPMethod {
    init(_ method: OpenAPIRuntime.HTTPMethod) throws {
        switch method {
        case .get: self = .get
        case .put: self = .put
        case .post: self = .post
        case .delete: self = .delete
        case .options: self = .options
        case .head: self = .head
        case .patch: self = .patch
        default: throw ComputeTransportError.unsupportedHTTPMethod(method.rawValue)
        }
    }
}
