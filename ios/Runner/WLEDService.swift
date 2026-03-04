import Foundation

/// WLED 原生 HTTP 通信层
/// 供 App Intents 直接调用，无需启动 Flutter Engine
@available(iOS 16.0, *)
final class WLEDService {
    
    static let shared = WLEDService()
    static let appGroupId = "group.ink.ainx.flux"
    static let devicesKey = "flutter.flux_devices"
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Device Management
    
    struct Device: Codable {
        let id: String
        let name: String
        let ip: String
        let port: Int?
        
        var baseUrl: String { "http://\(ip):\(port ?? 80)" }
    }
    
    /// 从 App Groups UserDefaults 读取设备列表
    func getDevices() -> [Device] {
        guard let defaults = UserDefaults(suiteName: WLEDService.appGroupId),
              let jsonStr = defaults.string(forKey: WLEDService.devicesKey),
              let data = jsonStr.data(using: .utf8) else {
            return []
        }
        
        do {
            let devices = try JSONDecoder().decode([Device].self, from: data)
            return devices
        } catch {
            print("[WLEDService] Failed to decode devices: \(error)")
            return []
        }
    }
    
    // MARK: - WLED API
    
    /// 开关控制
    func setOn(host: String, port: Int, on: Bool) async throws {
        try await postState(host: host, port: port, body: ["on": on])
    }
    
    /// 设置亮度 (0-255)
    func setBrightness(host: String, port: Int, brightness: Int) async throws {
        let bri = max(0, min(255, brightness))
        try await postState(host: host, port: port, body: ["bri": bri])
    }
    
    /// 设置颜色 (RGB)
    func setColor(host: String, port: Int, r: Int, g: Int, b: Int) async throws {
        let body: [String: Any] = [
            "seg": [["col": [[r, g, b]]]]
        ]
        try await postState(host: host, port: port, body: body)
    }
    
    /// 设置效果
    func setEffect(host: String, port: Int, effectId: Int) async throws {
        let body: [String: Any] = [
            "seg": [["fx": effectId]]
        ]
        try await postState(host: host, port: port, body: body)
    }
    
    /// 加载预设
    func loadPreset(host: String, port: Int, presetId: Int) async throws {
        try await postState(host: host, port: port, body: ["ps": presetId])
    }
    
    /// 获取效果列表
    func getEffects(host: String, port: Int) async throws -> [String] {
        let data = try await get(host: host, port: port, path: "/json/effects")
        return try JSONDecoder().decode([String].self, from: data)
    }
    
    /// 获取预设列表  
    func getPresets(host: String, port: Int) async throws -> [(id: Int, name: String)] {
        let data = try await get(host: host, port: port, path: "/json/presets")
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        return dict.compactMap { key, value -> (Int, String)? in
            guard let id = Int(key), id > 0,
                  let preset = value as? [String: Any],
                  let name = preset["n"] as? String else {
                return nil
            }
            return (id, name)
        }.sorted { $0.0 < $1.0 }
    }
    
    // MARK: - HTTP Helpers
    
    private func postState(host: String, port: Int, body: [String: Any]) async throws {
        let url = URL(string: "http://\(host):\(port)/json/state")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WLEDError.requestFailed
        }
    }
    
    private func get(host: String, port: Int, path: String) async throws -> Data {
        let url = URL(string: "http://\(host):\(port)\(path)")!
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WLEDError.requestFailed
        }
        return data
    }
}

enum WLEDError: LocalizedError {
    case requestFailed
    case deviceNotFound
    case noDevices
    
    var errorDescription: String? {
        switch self {
        case .requestFailed: return "无法连接 WLED 设备，请检查网络连接"
        case .deviceNotFound: return "未找到指定设备"
        case .noDevices: return "未添加任何设备，请先在 W-Link 中添加设备"
        }
    }
}

// MARK: - Effect Name Translations

/// WLED 效果中英文翻译表
let wledEffectTranslations: [String: String] = [
    "Solid": "纯色", "Blink": "闪烁", "Breathe": "呼吸", "Wipe": "擦除",
    "Wipe Random": "随机擦除", "Random Colors": "随机色彩", "Sweep": "扫描",
    "Dynamic": "动态", "Colorloop": "色彩循环", "Rainbow": "彩虹",
    "Scan": "扫描", "Scan Dual": "双向扫描", "Fade": "渐变",
    "Theater": "剧场", "Theater Rainbow": "剧场彩虹", "Running": "跑马灯",
    "Saw": "锯齿", "Twinkle": "闪烁星", "Dissolve": "溶解",
    "Dissolve Rnd": "随机溶解", "Sparkle": "火花", "Sparkle Dark": "暗火花",
    "Sparkle+": "火花+", "Strobe": "频闪", "Strobe Rainbow": "彩虹频闪",
    "Strobe Mega": "超级频闪", "Blink Rainbow": "彩虹闪烁", "Android": "安卓",
    "Chase": "追逐", "Chase Random": "随机追逐", "Chase Rainbow": "彩虹追逐",
    "Chase Flash": "闪光追逐", "Chase Flash Rnd": "随机闪光追逐",
    "Rainbow Runner": "彩虹跑者", "Colorful": "多彩", "Traffic Light": "红绿灯",
    "Sweep Random": "随机扫描", "Chase 2": "追逐2", "Aurora": "极光",
    "Stream": "流光", "Scanner": "扫描器", "Lighthouse": "灯塔",
    "Fireworks": "烟花", "Rain": "雨滴", "Tetrix": "俄罗斯方块",
    "Fire Flicker": "火焰闪烁", "Gradient": "渐变", "Loading": "加载中",
    "Police": "警灯", "Fairy": "仙女", "Two Dots": "双点",
    "Fairytwinkle": "仙女闪烁", "Running Dual": "双向跑马灯",
    "Halloween": "万圣节", "Chase 3": "追逐3", "Tri Wipe": "三色擦除",
    "Tri Fade": "三色渐变", "Lightning": "闪电", "ICU": "重症监护",
    "Multi Comet": "多彗星", "Scanner Dual": "双向扫描器", "Stream 2": "流光2",
    "Oscillate": "振荡", "Pride 2015": "骄傲2015", "Juggle": "杂耍",
    "Palette": "调色板", "Fire 2012": "火焰2012", "Colorwaves": "色彩波浪",
    "Bpm": "节拍", "Fill Noise": "噪点填充",
    "Noise 1": "噪点1", "Noise 2": "噪点2", "Noise 3": "噪点3", "Noise 4": "噪点4",
    "Colortwinkles": "彩色闪烁", "Lake": "湖泊", "Meteor": "流星",
    "Meteor Smooth": "平滑流星", "Railway": "铁路", "Ripple": "涟漪",
    "Twinklefox": "狐狸闪烁", "Twinklecat": "猫咪闪烁",
    "Halloween Eyes": "万圣节眼睛", "Solid Pattern": "纯色图案",
    "Solid Pattern Tri": "三色纯色图案", "Spots": "光斑", "Spots Fade": "渐变光斑",
    "Glitter": "闪光", "Candle": "蜡烛", "Fireworks Starburst": "星爆烟花",
    "Fireworks 1D": "一维烟花", "Bouncing Balls": "弹跳球",
    "Sinelon": "正弦", "Sinelon Dual": "双正弦", "Sinelon Rainbow": "彩虹正弦",
    "Popcorn": "爆米花", "Drip": "水滴", "Plasma": "等离子",
    "Percent": "百分比", "Ripple Rainbow": "彩虹涟漪", "Heartbeat": "心跳",
    "Pacifica": "太平洋", "Candle Multi": "多彩蜡烛", "Solid Glitter": "闪光纯色",
    "Sunrise": "日出", "Phased": "相位", "Twinkleup": "闪烁上升",
    "Noise Pal": "调色板噪点", "Sine": "正弦波", "Phased Noise": "噪点相位",
    "Flow": "流动", "Chunchun": "啾啾", "Dancing Shadows": "舞动阴影",
    "Washing Machine": "洗衣机", "Candy Cane": "拐杖糖", "Blends": "混合",
    "TV Simulator": "电视模拟", "Dynamic Smooth": "平滑动态",
    // 2D
    "Spaceships": "飞船", "Crazy Bees": "疯狂蜜蜂", "Ghost Rider": "恶灵骑士",
    "Blobs": "水滴球", "Scrolling Text": "滚动文字", "Drift Rose": "漂移玫瑰",
    "Distortion Waves": "扭曲波浪", "Soap": "肥皂泡", "Octopus": "章鱼",
    "Waving Cell": "波动细胞", "Pixels": "像素", "Pixelwave": "像素波",
    "Juggles": "杂耍球", "Matripix": "矩阵像素", "Gravimeter": "重力计",
    "Plasmoid": "等离子体", "Puddles": "水坑", "Midnoise": "正午噪点",
    "Noisemeter": "噪点计", "Freqwave": "频率波", "Freqmatrix": "频率矩阵",
    "GEQ": "图形均衡器", "Waterfall": "瀑布", "Freqpixels": "频率像素",
    "Noisefire": "噪点火焰", "Noise2D": "2D噪点", "Perlin Move": "柏林移动",
    "Ripple Peak": "涟漪峰值", "Firenoise": "火焰噪点",
    "Squared Swirl": "方形漩涡", "Fire2D": "2D火焰", "DNA": "DNA螺旋",
    "Matrix": "黑客帝国", "Metaballs": "融合球", "DJ Light": "DJ灯光",
    "Drift": "漂移", "Waverly": "波浪利", "Sun Radiation": "太阳辐射",
    "Colored Bursts": "彩色爆发", "Julia": "朱利亚集", "Game Of Life": "生命游戏",
    "Tartan": "格子呢", "Polar Lights": "极地光", "Swirl": "漩涡",
    "Lissajous": "李萨如曲线", "Frizzles": "卷曲", "Plasma Ball": "等离子球",
    "Flow Stripe": "流动条纹", "Hiphotic": "催眠", "Sindots": "正弦点",
    "DNA Spiral": "DNA螺旋", "Black Hole": "黑洞", "Wavesins": "波浪正弦",
    "Akemi": "明美",
]

/// 翻译效果名称（英文 → 中文）
func translateEffectName(_ name: String) -> String {
    // 获取系统是否使用中文
    let isChinese = Locale.current.languageCode?.hasPrefix("zh") == true
    
    // 如果不是中文环境，直接返回原英文名
    guard isChinese else { return name }
    
    let clean = name.trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: "^[\\*\\s]+", with: "", options: .regularExpression)
    
    if let translated = wledEffectTranslations[clean] {
        return translated
    }
    // Case-insensitive fallback
    let lower = clean.lowercased()
    for (key, value) in wledEffectTranslations {
        if key.lowercased() == lower { return value }
    }
    return name
}

