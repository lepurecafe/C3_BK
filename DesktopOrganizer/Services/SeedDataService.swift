import Foundation
import SwiftData

// SwiftData 초기 데이터가 필요해질 때를 위한 자리입니다.
//
// 현재 MVP 흐름은 사용자가 직접 박스와 메모를 생성하는 것이므로 seed 데이터는 만들지 않습니다.
// 그래도 서비스 파일을 남겨두면 나중에 예시 박스/메모를 넣거나 마이그레이션 준비 코드를 붙일 위치가 명확해집니다.
@MainActor
enum SeedDataService {
    static func ensureReady(boxes: [OrganizerBox], context: ModelContext) {
        // 지금은 호출되지 않는 준비 함수입니다.
        // 나중에 "처음 실행하면 예시 박스 1개를 자동 생성" 같은 요구가 생기면
        // boxes가 비어 있는지 확인하고 context.insert(...)를 넣는 위치가 됩니다.
        _ = boxes
        _ = context
    }
}
