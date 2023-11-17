import Foundation
import OpenAPIRuntime
import HTTPTypes
import Compute

public final class ComputeTransport {
    internal var router: Compute.Router

    public init(router: Compute.Router) {
        self.router = router
    }
}

extension ComputeTransport: ServerTransport {
    public func register(
        _ handler: @Sendable @escaping (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws -> (HTTPResponse, HTTPBody?),
        method: HTTPRequest.Method,
        path: String
    ) throws {
        router.on(
            method,
            path
            ) { computeRequest in
                let request = try await HTTPTypes.HTTPRequest(computeRequest)
                let body = try await OpenAPIRuntime.HTTPBody(computeRequest)
                let requestMetadata = try OpenAPIRuntime.ServerRequestMetadata(
                    from: computeRequest,
                    forPath: path
                )
                return try await handler(request, body, requestMetadata)
            }
        }
}

extension [PathComponent] {
    init(_ path: String) {
        self = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map { parameter in
            if parameter.first == "{", parameter.last == "}" {
                return .parameter(String(parameter.dropFirst().dropLast()))
            } else {
                return .constant(String(parameter))
            }
        }
    }
}

extension Compute.Router {

    @discardableResult
    func on(
        _ method: HTTPRequest.Method,
        _ path: String,
        use closure: @escaping (IncomingRequest) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
    ) -> Compute.Router {
        let handler: (IncomingRequest, OutgoingResponse) async throws -> Void =  { request, response in
            let result = try await closure(request)
            response.status(result.0.status.code)
            result.0.headerFields.forEach {
                response.header($0.name.rawName, $0.value)
            }
            guard let body = result.1 else {
                try await response.end()
                return
            }
            switch body.length {
            case let .known(length):
                try await response.send(Data(collecting: body, upTo: length))
            case .unknown:
                try await response.send(Data(collecting: body, upTo: .max))
            }
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

extension HTTPTypes.HTTPRequest {
    init(_ computeRequest: Compute.IncomingRequest) async throws {
        let headerFields: HTTPTypes.HTTPFields = .init(computeRequest.headers)
        let method = try HTTPTypes.HTTPRequest.Method(computeRequest.method)
        let queries = computeRequest.url.query.map { "?\($0)" } ?? ""

        self.init(
            method: method,
            scheme: computeRequest.url.scheme,
            authority: computeRequest.url.host(),
            path: computeRequest.url.path() + queries,
            headerFields: headerFields
        )
    }
}

extension OpenAPIRuntime.HTTPBody {
    convenience init(_ computeRequest: Compute.IncomingRequest) async throws {
        let contentLength = computeRequest.headers.entries().first { $0.key == "content-length"}.map { Int($0.value) }
        await self.init(
            try computeRequest.body.data(),
            length: contentLength?.map { .known($0) } ?? .unknown,
            iterationBehavior: .single
        )
    }
}

extension OpenAPIRuntime.ServerRequestMetadata {
    init(from computeRequest: Compute.IncomingRequest, forPath path: String) throws {
        self.init(pathParameters: try .init(from: computeRequest, forPath: path))
    }
}

extension Dictionary<String, Substring> {
    init(from computeRequest: Compute.IncomingRequest, forPath path: String) throws {
        let keysAndValues = try [PathComponent](path).compactMap { component throws -> String? in
            guard case let .parameter(parameter) = component else {
                return nil
            }
            return parameter
        }.map { parameter -> (String, Substring) in
            guard let value = computeRequest.searchParams[parameter] else {
                throw ComputeTransportError.missingRequiredPathParameter(parameter)
            }
            return (parameter, Substring(value))
        }
        let pathParameterDictionary = try Dictionary(keysAndValues, uniquingKeysWith: { _, _ in
            throw ComputeTransportError.duplicatePathParameter(keysAndValues.map(\.0))
        })
        self = pathParameterDictionary
    }
}

extension HTTPTypes.HTTPFields {
    init(_ headers: Compute.Headers) {
        self.init(headers.entries().compactMap { name, value in
            guard let name = HTTPField.Name(name) else {
                return nil
            }
            return HTTPField(name: name, value: value)
        })
    }
}

extension HTTPTypes.HTTPRequest.Method {
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
    init(_ method: HTTPTypes.HTTPRequest.Method) throws {
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
