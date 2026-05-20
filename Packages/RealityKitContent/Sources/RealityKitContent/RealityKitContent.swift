import Foundation

// RealityKitContent는 앱 본체와 분리된 Swift Package입니다.
// Package 안의 .rkassets, .usda, .usdz 같은 리소스를 앱 코드에서 찾으려면 Bundle.module을 공개해야 합니다.
// BoxVolumeView는 이 값을 Entity(named:in:)의 in: 인자로 넘겨 TravelCaseScene을 로드합니다.
public let realityKitContentBundle = Bundle.module
