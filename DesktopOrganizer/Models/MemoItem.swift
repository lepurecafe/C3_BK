import Foundation
import SwiftData

// SwiftData에 저장되는 메모 기록입니다.
//
// MemoLabel이 창에 전달되는 일회성 값이라면,
// MemoItem은 앱 재실행 후에도 ControlPanel 목록에 다시 나타나는 영속 데이터입니다.
@Model
final class MemoItem {
    // MemoLabel.id와 맞춰서 저장된 메모와 열린 창을 연결해 생각할 수 있게 합니다.
    @Attribute(.unique) var id: UUID
    // 사용자가 입력한 메모 본문입니다.
    var text: String
    // ControlPanel의 @Query 정렬 기준입니다.
    var createdAt: Date
    // MemoLabel과 마찬가지로 Color 자체 대신 색상 배열 인덱스를 저장합니다.
    var colorIndex: Int = 0
    // 라벨 배경의 모서리 둥글기 값입니다.
    var cornerRadius: Double = 20.0
    // nil이면 아직 박스 밖에 떠 있는 메모이고,
    // 값이 있으면 해당 OrganizerBox.id를 가진 박스 안에 들어간 메모입니다.
    var containerBoxID: UUID?

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        colorIndex: Int = 0,
        cornerRadius: Double = 20.0,
        containerBoxID: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.colorIndex = colorIndex
        self.cornerRadius = cornerRadius
        self.containerBoxID = containerBoxID
    }
}
