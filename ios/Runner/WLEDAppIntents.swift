import AppIntents

// MARK: - Device Entity

/// WLED 设备实体，供快捷指令中选择设备
@available(iOS 16.0, *)
struct WLEDDeviceEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "WLED 设备")
    static var defaultQuery = WLEDDeviceQuery()
    
    var id: String
    var name: String
    var ip: String
    var port: Int
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(ip)")
    }
}

@available(iOS 16.0, *)
struct WLEDDeviceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WLEDDeviceEntity] {
        let all = getAllDeviceEntities()
        return all.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [WLEDDeviceEntity] {
        getAllDeviceEntities()
    }
    
    func defaultResult() async -> WLEDDeviceEntity? {
        getAllDeviceEntities().first
    }
    
    private func getAllDeviceEntities() -> [WLEDDeviceEntity] {
        WLEDService.shared.getDevices().map { device in
            WLEDDeviceEntity(
                id: device.id,
                name: device.name,
                ip: device.ip,
                port: device.port ?? 80
            )
        }
    }
}

// MARK: - Color Presets

/// 预设颜色枚举
@available(iOS 16.0, *)
enum WLEDColorPreset: String, AppEnum {
    case warmWhite = "warm_white"
    case coolWhite = "cool_white"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case cyan = "cyan"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case custom = "custom"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "颜色")
    
    static var caseDisplayRepresentations: [WLEDColorPreset: DisplayRepresentation] = [
        .warmWhite: "暖白 💡",
        .coolWhite: "冷白 🔆",
        .red: "红色 🔴",
        .orange: "橙色 🟠",
        .yellow: "黄色 🟡",
        .green: "绿色 🟢",
        .cyan: "青色 🩵",
        .blue: "蓝色 🔵",
        .purple: "紫色 🟣",
        .pink: "粉色 🩷",
        .custom: "自定义 RGB 🎨",
    ]
    
    var rgb: (r: Int, g: Int, b: Int)? {
        switch self {
        case .warmWhite: return (255, 180, 100)
        case .coolWhite: return (255, 255, 255)
        case .red:       return (255, 0, 0)
        case .orange:    return (255, 120, 0)
        case .yellow:    return (255, 200, 0)
        case .green:     return (0, 255, 0)
        case .cyan:      return (0, 255, 255)
        case .blue:      return (0, 0, 255)
        case .purple:    return (128, 0, 255)
        case .pink:      return (255, 50, 120)
        case .custom:    return nil
        }
    }
}

// MARK: - Effect Entity

/// WLED 效果实体，动态从设备获取效果列表
@available(iOS 16.0, *)
struct WLEDEffectEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "灯效")
    static var defaultQuery = WLEDEffectQuery()
    
    var id: String  // "deviceIp:effectId"
    var name: String
    var effectId: Int
    var deviceIp: String
    var devicePort: Int
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 16.0, *)
struct WLEDEffectQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WLEDEffectEntity] {
        let all = try await suggestedEntities()
        return all.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [WLEDEffectEntity] {
        // 从第一个在线设备获取效果列表
        let devices = WLEDService.shared.getDevices()
        guard let device = devices.first else { return [] }
        
        let ip = device.ip
        let port = device.port ?? 80
        
        do {
            let effects = try await WLEDService.shared.getEffects(host: ip, port: port)
            return effects.enumerated().map { index, name in
                // 使用刚刚在 WLEDService.swift 加的本地化函数
                let localizedName = translateEffectName(name)
                return WLEDEffectEntity(
                    id: "\(ip):\(index)",
                    name: localizedName,
                    effectId: index,
                    deviceIp: ip,
                    devicePort: port
                )
            }
        } catch {
            return []
        }
    }
    
    func defaultResult() async -> WLEDEffectEntity? {
        // 不在启动时发网络请求，避免阻塞
        return nil
    }
}

// MARK: - Toggle Intent

/// 开/关灯
@available(iOS 16.0, *)
struct ToggleWLEDIntent: AppIntent {
    static var title: LocalizedStringResource = "开/关 WLED 灯"
    static var description = IntentDescription("控制 WLED 设备的开关状态")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "设备")
    var device: WLEDDeviceEntity
    
    @Parameter(title: "开关", default: true)
    var turnOn: Bool
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await WLEDService.shared.setOn(host: device.ip, port: device.port, on: turnOn)
        let status = turnOn ? "已开启" : "已关闭"
        return .result(dialog: "\(device.name) \(status)")
    }
}

// MARK: - Brightness Intent

/// 设置亮度
@available(iOS 16.0, *)
struct SetBrightnessIntent: AppIntent {
    static var title: LocalizedStringResource = "设置 WLED 亮度"
    static var description = IntentDescription("调整 WLED 设备的亮度")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "设备")
    var device: WLEDDeviceEntity
    
    @Parameter(title: "亮度 (%)", default: 100)
    var brightness: Int
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let bri = max(0, min(255, Int(Double(min(100, max(0, brightness))) / 100.0 * 255.0)))
        try await WLEDService.shared.setBrightness(host: device.ip, port: device.port, brightness: bri)
        return .result(dialog: "\(device.name) 亮度已设为 \(brightness)%")
    }
}

// MARK: - Color Intent

/// 设置颜色（预设 + 自定义）
@available(iOS 16.0, *)
struct SetColorIntent: AppIntent {
    static var title: LocalizedStringResource = "设置 WLED 颜色"
    static var description = IntentDescription("设置 WLED 设备的灯光颜色，可选择预设颜色或自定义 Hex 色值")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "设备")
    var device: WLEDDeviceEntity
    
    @Parameter(title: "颜色", default: .warmWhite)
    var color: WLEDColorPreset
    
    @Parameter(title: "自定义 Hex", default: "FF0000")
    var hexColor: String
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var r = 0, g = 0, b = 0
        
        if let preset = color.rgb {
            r = preset.r
            g = preset.g
            b = preset.b
        } else {
            // 解析 Hex 色值
            var hexString = hexColor.trimmingCharacters(in: .whitespacesAndNewlines)
            if hexString.hasPrefix("#") {
                hexString.remove(at: hexString.startIndex)
            }
            if hexString.count == 6, let rgbValue = Int(hexString, radix: 16) {
                r = (rgbValue >> 16) & 0xFF
                g = (rgbValue >> 8) & 0xFF
                b = rgbValue & 0xFF
            } else {
                r = 255; g = 255; b = 255 // 默认白色
            }
        }
        
        try await WLEDService.shared.setColor(host: device.ip, port: device.port, r: r, g: g, b: b)
        
        return .result(dialog: "🎨 \(device.name) 颜色已设置")
    }
}

// MARK: - Effect Intent

/// 设置效果（从设备动态获取效果列表）
@available(iOS 16.0, *)
struct SetEffectIntent: AppIntent {
    static var title: LocalizedStringResource = "设置 WLED 效果"
    static var description = IntentDescription("从设备效果列表中选择灯效")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "设备")
    var device: WLEDDeviceEntity
    
    @Parameter(title: "效果")
    var effect: WLEDEffectEntity
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await WLEDService.shared.setEffect(host: device.ip, port: device.port, effectId: effect.effectId)
        return .result(dialog: "\(device.name) 已切换为「\(effect.name)」")
    }
}

// MARK: - Preset Intent

/// 加载预设
@available(iOS 16.0, *)
struct LoadPresetIntent: AppIntent {
    static var title: LocalizedStringResource = "加载 WLED 预设"
    static var description = IntentDescription("加载 WLED 设备上保存的预设")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "设备")
    var device: WLEDDeviceEntity
    
    @Parameter(title: "预设编号", default: 1)
    var presetId: Int
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await WLEDService.shared.loadPreset(host: device.ip, port: device.port, presetId: presetId)
        return .result(dialog: "\(device.name) 已加载预设 \(presetId)")
    }
}

// MARK: - Shortcuts Provider

/// 注册系统快捷指令
@available(iOS 16.0, *)
struct WLEDShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleWLEDIntent(),
            phrases: [
                "用\(.applicationName)开灯",
                "用\(.applicationName)关灯",
                "\(.applicationName)开关灯"
            ],
            shortTitle: "开/关灯",
            systemImageName: "lightbulb.fill"
        )
        AppShortcut(
            intent: SetBrightnessIntent(),
            phrases: [
                "用\(.applicationName)设置亮度",
                "\(.applicationName)调亮度"
            ],
            shortTitle: "设置亮度",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: SetColorIntent(),
            phrases: [
                "用\(.applicationName)设置颜色",
                "\(.applicationName)换颜色"
            ],
            shortTitle: "设置颜色",
            systemImageName: "paintpalette.fill"
        )
        AppShortcut(
            intent: SetEffectIntent(),
            phrases: [
                "用\(.applicationName)切换效果",
                "\(.applicationName)换灯效"
            ],
            shortTitle: "设置效果",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: LoadPresetIntent(),
            phrases: [
                "用\(.applicationName)加载预设",
                "\(.applicationName)切预设"
            ],
            shortTitle: "加载预设",
            systemImageName: "star.fill"
        )
    }
}
