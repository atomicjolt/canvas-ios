//
// Copyright (C) 2018-present Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

extension UIColor {
    // MARK: Hex ARGB Handling

    public convenience init?(hexString: String?) {
        guard let hexString = hexString, hexString.hasPrefix("#"), let num = UInt(hexString.dropFirst(), radix: 16) else { return nil }
        var r: UInt = 0, g: UInt = 0, b: UInt = 0, a: UInt = 255
        switch hexString.count - 1 {
        case 8:
            a = (num & 0xff000000) >> 24
            fallthrough
        case 6:
            r = (num & 0xff0000) >> 16
            g = (num & 0x00ff00) >> 8
            b = (num & 0x0000ff) >> 0
        case 4:
            a = ((num & 0xf000) >> 8) + ((num & 0xf000) >> 12)
            fallthrough
        case 3:
            r = ((num & 0xf00) >> 4) + ((num & 0xf00) >> 8)
            g = ((num & 0x0f0) >> 0) + ((num & 0x0f0) >> 4)
            b = ((num & 0x00f) << 4) + ((num & 0x00f) >> 0)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }

    public var hexString: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1
        getRed(&red, green: &green, blue: &blue, alpha: &alpha) // assume success
        let toInt = { (n: CGFloat) in return Int(max(0.0, min(1.0, n)) * 255) }
        let num = (toInt(alpha) << 24) + (toInt(red) << 16) + (toInt(green) << 8) + toInt(blue)
        return "#\(String(num, radix: 16))".replacingOccurrences(of: "#ff", with: "#")
    }

    // MARK: Styleguide Colors

    /// Loads the named Canvas styleguide color from assets, accounting for contrast
    public static func named(_ name: Name, inHighContrast: Bool = UIAccessibility.isDarkerSystemColorsEnabled) -> UIColor {
        let named = inHighContrast ? "\(name)HighContrast" : "\(name)"
        return UIColor(named: named, in: .core, compatibleWith: nil) ?? .black
    }

    public enum Name: String {
        case ash, barney, crimson, electric, fire, shamrock, licorice, oxford, porcelain, tiara, white
        case backgroundAlert, backgroundDanger, backgroundDark, backgroundDarkest, backgroundInfo, backgroundLight, backgroundLightest, backgroundMedium, backgroundSuccess, backgroundWarning
        case borderAlert, borderDanger, borderDark, borderDarkest, borderDebug, borderInfo, borderLight, borderLightest, borderMedium, borderSuccess, borderWarning
        case textAlert, textDanger, textDark, textDarkest, textInfo, textLight, textLightest, textSuccess, textWarning
    }

    // MARK: Contrast

    /// Relative luminance as defined by WCAG 2.0
    ///
    /// https://www.w3.org/TR/WCAG20/#relativeluminancedef
    /// `0.0` for darkest black and `1.0` for lightest white.
    public var luminance: CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: nil) // assume success
        let convert = { (c: CGFloat) -> CGFloat in
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * convert(red) + 0.7152 * convert(green) + 0.0722 * convert(blue)
    }

    /// Contrast ratio as defined by WCAG 2.0
    ///
    /// http://www.w3.org/TR/WCAG20/#contrast-ratiodef
    /// `1.0` for identical colors and `21.0` for black against white.
    public func contrast(against: UIColor) -> CGFloat {
        let lum1 = luminance + 0.05
        let lum2 = against.luminance + 0.05
        return lum1 > lum2 ? lum1 / lum2 : lum2 / lum1
    }

    /// Get a sufficiently contrasting color based on the current color.
    ///
    /// If the user asked for more contrast, and there isn't enough, return a high enough contrasting color.
    /// This is intended to be used with branding colors
    public func ensureContrast(against: UIColor, inHighContrast: Bool = UIAccessibility.isDarkerSystemColorsEnabled) -> UIColor {
        let minRatio: CGFloat = 4.5
        guard inHighContrast && contrast(against: against) < minRatio else { return self }

        // This can iterate up to 200ish times, if perfomance becomes a problem we can instead
        // return against.luminance < 0.5 ? .white : .black

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 1
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let delta: CGFloat = against.luminance < 0.5 ? 0.01 : -0.01
        var color = self
        while color.contrast(against: against) < minRatio, saturation >= 0.0, saturation <= 1.0 {
            if brightness >= 0.0, brightness <= 1.0 {
                brightness += delta // first modify brightness
            } else {
                saturation -= 0.01 // then desaturate if needed
            }
            color = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
        return color
    }
}