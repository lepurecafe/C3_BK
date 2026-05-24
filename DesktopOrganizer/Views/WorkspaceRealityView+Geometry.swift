import RealityKit
import SwiftUI

// 2D drag translation을 3D 위치로 바꾸고, attachment entity가 사용자를 향하도록 설정하는 보조 함수들입니다.
//
// 교재 연결:
// - 5장: entity 탭과 선택 상태 처리하기
// - 7장: 내장 3D animation 재생하기
// - 10장: 드래그앤드롭으로 메모를 공간에 열기
// - 11장: SwiftUI 카드 UI를 공간 오브젝트처럼 다루기
extension WorkspaceRealityView {
    func spatialMemoPosition(for translation: CGSize) -> SIMD3<Float> {
        // SwiftUI DragGesture는 화면의 point 단위로 이동량을 줍니다.
        // RealityKit 공간은 meter 단위에 가까운 Float 좌표를 쓰므로 memoDragMetersPerPoint로 축소합니다.
        // y는 화면에서 아래로 끌면 값이 +가 되지만, 3D 공간에서는 위가 +라서 부호를 반대로 둡니다.
        SIMD3<Float>(
            Float(translation.width) * memoDragMetersPerPoint,
            0.34 - Float(translation.height) * memoDragMetersPerPoint,
            0.03
        )
    }

    func spatialMemoDropPosition(in boxID: UUID, translation: CGSize) -> SIMD3<Float>? {
        // 드래그 중 preview는 박스 기준 상대 위치처럼 움직입니다.
        // 실제 공간 메모로 열 때는 boxRoot의 현재 위치를 더해 ImmersiveSpace root 기준 좌표로 바꿉니다.
        guard let boxRoot = sceneState.boxRoots[boxID] else {
            return nil
        }

        return boxRoot.position + spatialMemoPosition(for: translation)
    }

    func spatialMemoMovement(for translation: CGSize) -> SIMD3<Float> {
        // 이미 공간에 열린 메모를 옮길 때는 시작 위치에 "이동량"만 더합니다.
        // 그래서 기본 높이 0.34를 포함하지 않고 translation을 작은 3D delta로만 변환합니다.
        SIMD3<Float>(
            Float(translation.width) * memoDragMetersPerPoint,
            -Float(translation.height) * memoDragMetersPerPoint,
            0
        )
    }

    func transformMatrix(for position: SIMD3<Float>) -> simd_float4x4 {
        // WorldAnchor API는 단순 위치가 아니라 4x4 transform matrix를 받습니다.
        // 현재 앱은 회전 조작을 제공하지 않으므로 identity matrix에 위치 성분만 채워 넘깁니다.
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
        return transform
    }

    func configureMemoBillboard(_ entity: Entity) {
        // 교재 11장: SwiftUI attachment는 얇은 카드처럼 보이므로,
        // BillboardComponent로 사용자가 읽기 쉬운 방향을 유지합니다.
        var billboard = BillboardComponent()
        billboard.blendFactor = 0.75
        entity.components.set(billboard)
    }

    func configureOpenedMemoEntity(_ entity: Entity) {
        // 열린 메모는 읽을 수 있어야 하고, hover/drag/button 입력도 받아야 합니다.
        // Billboard는 가독성, InputTarget은 gesture/button 입력, HoverEffect는 시선/포인터 반응을 담당합니다.
        configureMemoBillboard(entity)
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())
    }

    func dragDistance(_ translation: CGSize) -> CGFloat {
        // x/y 이동량을 피타고라스 공식으로 하나의 거리로 바꿉니다.
        // 가로든 세로든 충분히 끌면 같은 기준으로 "열기 준비"가 됩니다.
        sqrt((translation.width * translation.width) + (translation.height * translation.height))
    }

    func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
        // 교재 7장: animation이 root가 아니라 child entity에 들어 있을 수도 있어서 재귀적으로 찾습니다.
        if let animation = entity.availableAnimations.first {
            return animation
        }

        for child in entity.children {
            if let animation = firstAvailableAnimation(in: child) {
                return animation
            }
        }

        return nil
    }

    func boxID(for entity: Entity) -> UUID? {
        // 교재 5장: 사용자가 탭한 entity가 모델의 child일 수 있으므로 부모를 따라 올라가며 boxRoot 이름을 찾습니다.
        if let id = boxID(from: entity.name) {
            return id
        }

        guard let parent = entity.parent else {
            return nil
        }

        return boxID(for: parent)
    }

    func boxID(from entityName: String) -> UUID? {
        // renderBox에서 boxRoot.name을 "WorkspaceBox:<UUID>"로 정해 두었기 때문에
        // targeted gesture가 잡은 entity의 부모들을 올라가다 이 이름을 만나면 박스 id를 복원할 수 있습니다.
        guard entityName.hasPrefix("WorkspaceBox:") else {
            return nil
        }

        let rawID = entityName.replacingOccurrences(of: "WorkspaceBox:", with: "")
        return UUID(uuidString: rawID)
    }

    func boxEntityName(for id: UUID) -> String {
        "WorkspaceBox:\(id.uuidString)"
    }
}
