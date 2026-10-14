public enum BluetoothDeviceKind: Equatable, Sendable {
    case headphones, speaker, keyboard, mouse, gamepad, phone, other

    /// Bluetooth Class of Device: major class and 6-bit minor class.
    public static func from(major: UInt32, minor: UInt32) -> Self {
        switch major {
        case 0x04:
            if [0x01, 0x02, 0x06].contains(minor) { return .headphones }
            if minor == 0x05 { return .speaker }
            return .other
        case 0x05:
            if minor & 0x0F == 0x02 { return .gamepad }
            switch minor & 0x30 {
            case 0x10: return .keyboard
            case 0x20, 0x30: return .mouse
            default: return .other
            }
        case 0x02: return .phone
        default: return .other
        }
    }

    public var symbolName: String {
        switch self {
        case .headphones: "headphones"
        case .speaker: "hifispeaker.fill"
        case .keyboard: "keyboard"
        case .mouse: "computermouse.fill"
        case .gamepad: "gamecontroller.fill"
        case .phone: "iphone"
        case .other: "wave.3.right"
        }
    }
}
