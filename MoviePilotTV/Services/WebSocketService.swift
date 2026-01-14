//
//  WebSocketService.swift
//  MoviePilotTV
//
//  Created on 2025-12-31.
//

import Foundation

// 进度消息模型
struct ProgressMessage: Codable {
    let enable: Bool
    let value: Double
    let text: String
    let data: [String: AnyCodable]?
}

// 用于解码任意类型的值
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        default:
            try container.encodeNil()
        }
    }
}

// SSE（Server-Sent Events）服务
@MainActor
class SSEService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var latestProgress: ProgressMessage?
    
    private var task: URLSessionDataTask?
    private var urlSession: URLSession?
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5分钟超时
        config.httpAdditionalHeaders = ["Accept": "text/event-stream"]
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ [SSE] 无效的 URL: \(urlString)")
            return
        }
        
        disconnect()
        
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        // 添加认证信息
        let token = AuthenticationManager.shared.accessToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        print("🔵 [SSE] 连接到: \(urlString)")
        
        task = urlSession?.dataTask(with: request)
        task?.resume()
        isConnected = true
    }
    
    func disconnect() {
        task?.cancel()
        task = nil
        isConnected = false
        print("🔵 [SSE] 断开连接")
    }
    
    private func parseSSEData(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        
        // SSE 格式: data: {...}\n\n
        let lines = text.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("data:") {
                let jsonString = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                
                if let jsonData = jsonString.data(using: .utf8) {
                    do {
                        let progress = try JSONDecoder().decode(ProgressMessage.self, from: jsonData)
                        Task { @MainActor in
                            self.latestProgress = progress
                            print("✅ [SSE] 进度: \(progress.value)% - \(progress.text)")
                        }
                    } catch {
                        print("❌ [SSE] 解析消息失败: \(error)")
                        print("   JSON: \(jsonString)")
                    }
                }
            }
        }
    }
}

// URLSessionDataDelegate
extension SSEService: URLSessionDataDelegate {
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task { @MainActor in
            self.parseSSEData(data)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ [SSE] 连接错误: \(error.localizedDescription)")
            } else {
                print("✅ [SSE] 连接正常关闭")
            }
            self.isConnected = false
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            print("🔵 [SSE] 响应状态码: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 200 {
                completionHandler(.allow)
            } else {
                print("❌ [SSE] 非200状态码: \(httpResponse.statusCode)")
                completionHandler(.cancel)
            }
        } else {
            completionHandler(.allow)
        }
    }
}

