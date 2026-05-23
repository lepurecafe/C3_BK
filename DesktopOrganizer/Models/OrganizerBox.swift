import Foundation
import SwiftData

// SwiftData에 저장되는 박스 기록입니다.
//
// OrganizerBox는 앱을 껐다 켜도 남아야 하는 박스 데이터입니다.
// ControlPanelView와 WorkspaceRealityView가 이 모델을 읽어 공간 속 entity를 복원합니다.
@Model
final class OrganizerBox {
    // @Attribute(.unique)는 같은 id가 중복 저장되지 않도록 하는 SwiftData 제약입니다.
    @Attribute(.unique) var id: UUID
    // ControlPanel 목록과 공간 속 attachment에 표시할 이름입니다.
    var name: String
    // @Query(sort:)에서 생성 순서대로 정렬할 때 사용합니다.
    var createdAt: Date
    // MVP에서는 아직 적극적으로 쓰지 않지만, 이후 박스 열림/닫힘 상태로 확장할 자리입니다.
    var isOpen: Bool = false
    // 사용자가 박스를 공간 안에서 옮긴 뒤 다시 열었을 때 복원할 위치입니다.
    // 실제 WorldAnchor를 붙이기 전까지는 이 좌표가 anchor 후보 위치 역할을 합니다.
    var posX: Float = 0
    var posY: Float = 1.0
    var posZ: Float = -1.0
    // 박스별 앵커 UI의 ON/OFF 상태입니다.
    // true이면 실제 WorldAnchor 또는 Simulator용 임시 잠금으로 보고 드래그 이동을 막습니다.
    var isAnchored: Bool = false
    // 실제 ARKit WorldAnchor 생성에 성공했을 때만 채워집니다.
    // Simulator fallback처럼 임시 잠금만 적용된 경우에는 nil로 남습니다.
    var worldAnchorIdentifier: String?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        isOpen: Bool = false,
        posX: Float = 0,
        posY: Float = 1.0,
        posZ: Float = -1.0,
        isAnchored: Bool = false,
        worldAnchorIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isOpen = isOpen
        self.posX = posX
        self.posY = posY
        self.posZ = posZ
        self.isAnchored = isAnchored
        self.worldAnchorIdentifier = worldAnchorIdentifier
    }
}
