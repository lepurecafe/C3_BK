import Foundation
import SwiftData

// SwiftData에 저장되는 메모 기록입니다.
//
// 앱 재실행 후에도 박스 안 메모와 공간 메모 상태를 복원하기 위한 영속 데이터입니다.
@Model
final class MemoItem {
    // SwiftData 안에서 메모를 식별하고, 공간 메모 attachment와 WorldAnchor를 같은 ID로 연결합니다.
    @Attribute(.unique) var id: UUID
    // 사용자가 입력한 메모 본문입니다.
    var text: String
    // ControlPanel의 @Query 정렬 기준입니다.
    var createdAt: Date
    // Color 자체 대신 MemoPalette.colors 배열 인덱스를 저장합니다.
    var colorIndex: Int = 0
    // nil이면 아직 박스 밖에 떠 있는 메모이고,
    // 값이 있으면 해당 OrganizerBox.id를 가진 박스 안에 들어간 메모입니다.
    var containerBoxID: UUID?
    // true이면 박스 안 목록에서 꺼내 공간 메모 attachment로 펼쳐진 상태입니다.
    var isSpatiallyPresented: Bool = false
    // 펼쳐진 공간 메모가 어느 박스에서 나왔는지 저장합니다.
    var spatialBoxID: UUID?
    // ImmersiveSpace root 기준 공간 메모 위치입니다. 다음 실행 때 같은 위치에 복원하는 기준이 됩니다.
    // 실제 물리 공간 고정은 spatialWorldAnchorIdentifier가 있을 때 WorldAnchor transform을 우선 사용합니다.
    var spatialPosX: Float = 0
    var spatialPosY: Float = 0
    var spatialPosZ: Float = 0
    // true이면 공간 메모 pin이 켜져 있어 WorldAnchor가 적용되었거나 Simulator용 임시 잠금 상태입니다.
    var isSpatiallyAnchored: Bool = false
    // 공간 메모를 실제 WorldAnchor에 연결할 때 사용하는 anchor id입니다.
    var spatialWorldAnchorIdentifier: String?

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        colorIndex: Int = 0,
        containerBoxID: UUID? = nil,
        isSpatiallyPresented: Bool = false,
        spatialBoxID: UUID? = nil,
        spatialPosition: SIMD3<Float> = .zero,
        isSpatiallyAnchored: Bool = false,
        spatialWorldAnchorIdentifier: String? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.colorIndex = colorIndex
        self.containerBoxID = containerBoxID
        self.isSpatiallyPresented = isSpatiallyPresented
        self.spatialBoxID = spatialBoxID
        self.spatialPosX = spatialPosition.x
        self.spatialPosY = spatialPosition.y
        self.spatialPosZ = spatialPosition.z
        self.isSpatiallyAnchored = isSpatiallyAnchored
        self.spatialWorldAnchorIdentifier = spatialWorldAnchorIdentifier
    }
}
