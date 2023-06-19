import XCTest
@testable import OpenAPICompute
import Compute
import OpenAPIRuntime

final class ComputeTransportTests: XCTestCase {

    var router: Router!

    override func setUp() async throws {
        router = Router()
    }

    func testHTTPMethodConversion() throws {
        try XCTAssert(function: Compute.HTTPMethod.init(_:), behavesAccordingTo: [
            (.get, .get),
            (.put, .put),
            (.post, .post),
            (.delete, .delete),
            (.options, .options),
            (.head, .head),
            (.patch, .patch)
        ])
        try XCTAssertThrowsError(Compute.HTTPMethod(.trace)) {
            guard case let ComputeTransportError.unsupportedHTTPMethod(name) = $0 else {
                XCTFail()
                return
            }
            XCTAssertEqual(name, "TRACE")
        }

        try XCTAssert(function: OpenAPIRuntime.HTTPMethod.init(_:), behavesAccordingTo: [
            (.get, .get),
            (.put, .put),
            (.post, .post),
            (.delete, .delete),
            (.options, .options),
            (.head, .head),
            (.patch, .patch),
        ])
        try XCTAssertThrowsError(OpenAPIRuntime.HTTPMethod(.query)) {
            guard case let ComputeTransportError.unsupportedHTTPMethod(name) = $0 else {
                XCTFail()
                return
            }
            XCTAssertEqual(name, "QUERY")
        }
    }

    private func XCTAssert<Input, Output>(
        function: (Input) throws -> Output,
        behavesAccordingTo expectations: [(Input, Output)],
        file: StaticString = #file,
        line: UInt = #line
    ) rethrows where Output: Equatable {
        for (input, output) in expectations {
            try XCTAssertEqual(function(input), output, file: file, line: line)
        }
    }
}
