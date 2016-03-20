import UIKit
import Alamofire

public typealias JSONDictionary = [String: AnyObject]

public protocol AlamofireEndpoint: RawRepresentable {
    typealias RawValue = StringLiteralType
    static var BaseURL: String { get }
    static var DefaultContentType: String { get }
}

public enum AlamofireRequestParameter: DictionaryLiteralConvertible {
    public typealias Key = String
    public typealias Value = AnyObject

    case JSONBody(JSONDictionary)
    case URLParameters(JSONDictionary)
    case ContentType(String)

    public init(dictionaryLiteral elements: (Key, Value)...) {
        var parameters: JSONDictionary = [:]
        for (key, value) in elements {
            parameters[key] = value
        }
        self = .URLParameters(parameters)
    }
}

public enum AlamofireRouter<T: AlamofireEndpoint where T.RawValue == StringLiteralType>: URLRequestConvertible, StringLiteralConvertible {
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    public typealias UnicodeScalarLiteralType = StringLiteralType

    case POST(T)
    case GET(T)
    case PATCH(T)
    case HEAD(T)

    indirect case MethodWithRequestParameters(AlamofireRouter, [AlamofireRequestParameter])

    var endpoint: T {
        switch self {
        case .POST(let endpoint):
            return endpoint

        case .GET(let endpoint):
            return endpoint

        case .PATCH(let endpoint):
            return endpoint

        case .HEAD(let endpoint):
            return endpoint

        case .MethodWithRequestParameters(let method, _):
            return method.endpoint
        }
    }

    var contentType: String {
        switch self {
        case .MethodWithRequestParameters(let router, let requestParameters):
            for parameter in requestParameters {
                if case .ContentType(let contentType) = parameter {
                    return contentType
                }
            }

            return router.contentType

        default:
            return T.DefaultContentType
        }
    }

    var HTTPMethod: String {
        switch self {
        case .POST:
            return "POST"

        case .GET:
            return "GET"

        case .PATCH:
            return "PATCH"

        case .HEAD:
            return "HEAD"

        case .MethodWithRequestParameters(let router, _):
            return router.HTTPMethod
        }
    }

    var parameters: JSONDictionary? {
        switch self {
        case .MethodWithRequestParameters(_, let requestParameters):
            for parameter in requestParameters {
                switch parameter {
                case .JSONBody(let parameters):
                    return parameters

                case .URLParameters(let parameters):
                    return parameters

                default:
                    break
                }
            }

            fallthrough

        default:
            return nil
        }
    }

    var encoding: ParameterEncoding {
        switch self {
        case .MethodWithRequestParameters(let router, let requestParameters):
            for parameter in requestParameters {
                switch parameter {
                case .JSONBody:
                    return ParameterEncoding.JSON

                default:
                    break
                }
            }

            return router.encoding

        default:
            return ParameterEncoding.URL
        }
    }

    public var URLRequest: NSMutableURLRequest {
        var URL = NSURL(string: T.self.BaseURL)!
        URL = URL.URLByAppendingPathComponent(endpoint.rawValue)
        let request = NSMutableURLRequest(URL: URL)

        request.HTTPMethod = HTTPMethod
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        return encoding.encode(request, parameters: parameters).0
    }

    init(_ stringValue: String) {
        self = .GET(T(rawValue: stringValue)!)
    }

    public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(value)
    }

    public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init(value)
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    // MARK: -

    public func with(parameters: JSONDictionary) -> AlamofireRouter {
        return with(.URLParameters(parameters))
    }

    public func with(parameters: AlamofireRequestParameter...) -> AlamofireRouter {
        if case AlamofireRouter.MethodWithRequestParameters(let router, var requestParameters) = self {
            requestParameters.appendContentsOf(parameters)
            return AlamofireRouter.MethodWithRequestParameters(router, requestParameters)
        }
        else {
            return AlamofireRouter.MethodWithRequestParameters(self, parameters)
        }
    }

    /**

     ```
     Router<Endpoint>.GET(.Users).responseJSON { (response: [JSONDictionary]?) in

     }
     ```

     */
    public func responseJSON<T>(completion: T -> Void) {
        Manager.sharedInstance.request(self).responseJSON { response in
            switch response.result {
            case .Success(let value):
                if let value = value as? T {
                    completion(value)
                }

            case .Failure:
                break
            }
        }
    }
}

public class AlamofireClient<T: AlamofireEndpoint where T.RawValue == StringLiteralType> {
    public typealias Router = AlamofireRouter<T>
    
    static func request(URLRequest: Router) -> Request {
        return Manager.sharedInstance.request(URLRequest)
    }
}