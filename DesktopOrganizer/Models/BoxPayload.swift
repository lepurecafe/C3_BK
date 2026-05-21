import Foundation

// 예전 volumetric 박스 창을 열 때 WindowGroup에 전달하던 값입니다.
//
// SwiftUI의 WindowGroup(id:for:)는 Hashable/Codable 값을 받아 새 창을 식별하고 복원합니다.
// 현재 앱의 박스 흐름은 WorkspaceRealityView의 entity-only 방식이므로,
// 이 타입은 레거시 BoxVolumeView를 참고할 때만 사용됩니다.
struct BoxPayload: Hashable, Codable, Identifiable {
    // 저장된 OrganizerBox와 같은 id를 쓰면 재열기 목록에서 같은 박스를 다시 여는 흐름을 추적하기 쉽습니다.
    var id: UUID = UUID()
    // 현재 UI에는 크게 쓰이지 않지만, 창 제목이나 디버깅 표시로 확장할 수 있는 박스 이름입니다.
    var name: String
    // ARKit이 감지한 책상 중심 또는 fallback 위치입니다.
    // 예전 volumetric window API는 openWindow payload의 위치를 직접 배치에 쓰지 않았습니다.
    var posX: Float = 0
    var posY: Float = -0.3
    var posZ: Float = -0.8

    init(
        id: UUID = UUID(),
        name: String,
        posX: Float = 0,
        posY: Float = -0.3,
        posZ: Float = -0.8
    ) {
        self.id = id
        self.name = name
        self.posX = posX
        self.posY = posY
        self.posZ = posZ
    }
}
