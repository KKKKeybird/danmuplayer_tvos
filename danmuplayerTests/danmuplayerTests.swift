//
//  danmuplayerTests.swift
//  danmuplayerTests
//
//  Created by keybird on 2025/8/5.
//

import XCTest
@testable import danmuplayer

final class DanDanPlayConfigTests: XCTestCase {
    
    func testConfigurationValidation() {
        // 测试配置验证功能
        let (isValid, errorMessage) = DanDanPlayConfig.validateConfiguration()
        
        // 在默认配置下应该是无效的（使用占位符）
        XCTAssertFalse(isValid, "默认配置应该是无效的")
        XCTAssertNotNil(errorMessage, "应该有错误信息")
    }
    
    func testIsConfiguredProperty() {
        // 测试 isConfigured 属性
        XCTAssertFalse(DanDanPlayConfig.isConfigured, "默认情况下应该未配置")
    }
    
    func testSecretKeyAccess() {
        // 测试 secretKey 访问
        let secretKey = DanDanPlayConfig.secretKey
        XCTAssertNotNil(secretKey, "secretKey 应该可以访问")
        XCTAssertEqual(secretKey, "YOUR_APP_SECRET", "默认应该是占位符")
    }
}

final class DanmakuParserTests: XCTestCase {
    
    func testParseCommentsFromEmptyData() {
        // 测试空数据解析
        let emptyData = Data()
        // 使用新的统一解析方法
        guard let commentResult = try? JSONDecoder().decode(DanDanPlayCommentResult.self, from: emptyData) else {
            // 空数据应该解析失败，这是预期行为
            return
        }
        let comments = commentResult.comments ?? []
        XCTAssertTrue(comments.isEmpty, "空数据应该返回空数组")
    }
    
    func testParseCommentsFromValidJSON() {
        // 测试有效JSON数据解析
        let jsonString = """
        {
            "count": 1,
            "comments": [
                {
                    "cid": 1,
                    "p": "5.0,1,16777215,user123",
                    "m": "测试弹幕"
                }
            ]
        }
        """
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            XCTFail("无法创建测试数据")
            return
        }
        
        // 使用新的统一解析方法
        guard let commentResult = try? JSONDecoder().decode(DanDanPlayCommentResult.self, from: jsonData) else {
            XCTFail("无法解析JSON数据")
            return
        }
        
        let comments = commentResult.comments ?? []
        let danmakuParams = comments.compactMap { $0.parsedParams }
        
        XCTAssertEqual(danmakuParams.count, 1, "应该解析出1条弹幕")
        
        let firstComment = danmakuParams.first!
        XCTAssertEqual(firstComment.time, 5.0, "弹幕时间应该为5.0秒")
        XCTAssertEqual(firstComment.mode, 1, "弹幕模式应该为1")
        XCTAssertEqual(firstComment.color, 16777215, "弹幕颜色应该为白色")
        XCTAssertEqual(firstComment.userId, "user123", "用户ID应该匹配")
        XCTAssertEqual(firstComment.content, "测试弹幕", "弹幕内容应该匹配")
    }
}

final class FileInfoExtractorTests: XCTestCase {
    
    func testFileInfoExtraction() {
        // 创建一个临时文件URL进行测试
        let tempURL = URL(fileURLWithPath: "/tmp/test_video.mp4")
        
        // 测试文件名提取
        let fileName = tempURL.lastPathComponent
        XCTAssertEqual(fileName, "test_video.mp4", "文件名应该正确提取")
        
        let fileNameWithoutExtension = (fileName as NSString).deletingPathExtension
        XCTAssertEqual(fileNameWithoutExtension, "test_video", "不带扩展名的文件名应该正确")
    }
}

final class NetworkErrorTests: XCTestCase {
    
    func testNetworkErrorDescriptions() {
        // 测试网络错误描述
        let errors: [NetworkError] = [
            .invalidURL,
            .connectionFailed,
            .invalidResponse,
            .noData,
            .parseError,
            .notFound,
            .authenticationFailed,
            .serverError(500)
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty, "错误描述不应该为空")
        }
    }
}
