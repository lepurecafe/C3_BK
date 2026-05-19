import Foundation
import SwiftData

// SwiftData에 저장되는 박스 기록입니다.
//
// BoxPayload가 "창을 열기 위한 값"이라면,
// OrganizerBox는 "앱을 껐다 켜도 남아야 하는 데이터"입니다.
// ControlPanelView의 @Query가 이 모델을 읽어 재열기 목록을 만듭니다.
@Model
final class OrganizerBox {
    // @Attribute(.unique)는 같은 id가 중복 저장되지 않도록 하는 SwiftData 제약입니다.
    @Attribute(.unique) var id: UUID
    // ControlPanel 목록과 BoxPayload에 표시할 이름입니다.
    var name: String
    // @Query(sort:)에서 생성 순서대로 정렬할 때 사용합니다.
    var createdAt: Date
    // MVP에서는 아직 적극적으로 쓰지 않지만, 이후 박스 열림/닫힘 상태로 확장할 자리입니다.
    var isOpen: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        isOpen: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isOpen = isOpen
    }
}
