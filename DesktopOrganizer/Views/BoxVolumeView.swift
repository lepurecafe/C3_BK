import RealityKit
import RealityKitContent
import SwiftUI

// 3D 여행 가방을 보여주는 volumetric window의 내용입니다.
//
// 열리는 경로:
// ControlPanelView.createBox()
// -> openWindow(id: "boxWindow", value: BoxPayload)
// -> DesktopOrganizerApp의 WindowGroup(id: "boxWindow")
// -> BoxVolumeView(payload:)
struct BoxVolumeView: View {
    // 박스 창을 열 때 전달된 값입니다.
    // 현재 뷰는 모델 표시와 회전에 집중하고 있어 payload를 직접 렌더링하지는 않지만,
    // 이후 이름 표시나 감지 위치 기반 배치로 확장할 때 여기서 사용할 수 있습니다.
    let payload: BoxPayload?

    // 드래그 중의 회전값입니다.
    @State private var horizontalRotation = CGFloat.zero
    @State private var verticalRotation = CGFloat.zero
    // 드래그가 끝난 뒤 누적된 회전값입니다.
    // 다음 드래그가 이전 회전 상태에서 이어지도록 저장합니다.
    @State private var endHorizontalRotation = CGFloat.zero
    @State private var endVerticalRotation = CGFloat.zero
    // RealityView 안에서 로드한 3D 모델과 열림 애니메이션입니다.
    // SwiftUI 버튼처럼 View 상태만으로 직접 제어할 수 없기 때문에,
    // 로드가 끝난 Entity/AnimationResource를 @State에 보관한 뒤 탭 제스처에서 사용합니다.
    @State private var boxEntity: Entity?
    @State private var openAnimation: AnimationResource?
    @State private var animationController: AnimationPlaybackController?
    @State private var isOpen = false
    @State private var isAnimating = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        // RealityKitContent Swift Package의 .rkassets 안에 있는 TravelCaseScene Entity를 로드합니다.
        // Model3D보다 직접적인 RealityKit 경로라서 모델의 실제 bounds를 읽고 창 안에 맞게 스케일을 조정할 수 있습니다.
        RealityView { content in
            guard let entity = try? await Entity(
                named: "TravelCaseScene",
                in: realityKitContentBundle
            ) else {
                return
            }

            let bounds = entity.visualBounds(relativeTo: nil)
            let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            if maxExtent > 0 {
                // maxExtent는 모델의 가로/세로/깊이 중 가장 긴 길이입니다.
                // 그 가장 긴 축이 targetSize가 되도록 같은 비율로 줄이거나 키우면,
                // 모델 모양은 찌그러지지 않고 volumetric window 안에 들어옵니다.
                let targetSize: Float = 0.35
                let uniformScale = targetSize / maxExtent
                entity.scale = SIMD3<Float>(repeating: uniformScale)
            }

            // RealityKit entity가 visionOS의 시선+핀치 입력을 받으려면
            // InputTargetComponent와 hit test에 사용할 CollisionShape가 필요합니다.
            // 실제 mesh가 하위 entity에 있을 수 있으므로 입력 컴포넌트는 계층 전체에 붙입니다.
            configureInputTargets(in: entity)
            entity.generateCollisionShapes(recursive: true)

            boxEntity = entity
            openAnimation = firstAvailableAnimation(in: entity)
            content.add(entity)
        }
            // 좌우 드래그는 y축 회전으로, 위아래 드래그는 x축 회전으로 연결합니다.
            .rotation3DEffect(.degrees(horizontalRotation), axis: .y)
            .rotation3DEffect(.degrees(-verticalRotation), axis: .x)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // translation 값에 이전 누적 회전을 더해 자연스럽게 이어지는 회전을 만듭니다.
                        horizontalRotation = value.translation.width + endHorizontalRotation
                        verticalRotation = value.translation.height + endVerticalRotation
                    }
                    .onEnded { _ in
                        // 드래그가 끝난 지점을 다음 드래그의 시작 기준으로 저장합니다.
                        endHorizontalRotation = horizontalRotation
                        endVerticalRotation = verticalRotation
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .targetedToAnyEntity()
                    .onEnded { _ in
                        toggleBoxOpenState()
                    }
            )
    }

    private func toggleBoxOpenState() {
        guard !isAnimating, let entity = boxEntity, let animation = openAnimation else {
            return
        }

        if isOpen {
            closeBox(entity: entity, animation: animation)
        } else {
            openBox(entity: entity, animation: animation)
        }
    }

    private func openBox(entity: Entity, animation: AnimationResource) {
        animationTask?.cancel()
        animationController?.stop()

        // 열 때는 asset에 들어 있는 Open 애니메이션을 정상 방향으로 재생합니다.
        let controller = entity.playAnimation(animation, transitionDuration: 0, startsPaused: true)
        let duration = max(controller.duration, 0.1)
        controller.speed = 1
        controller.time = 0

        animationController = controller
        isAnimating = true
        controller.resume()

        animationTask = Task { @MainActor in
            let nanoseconds = UInt64(duration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }

            controller.pause()
            controller.time = duration
            isOpen = true
            isAnimating = false
        }
    }

    private func closeBox(entity: Entity, animation: AnimationResource) {
        animationTask?.cancel()
        animationController?.stop()

        // RealityKit의 imported skeletal animation은 negative speed가 기기에서
        // 다시 첫 프레임부터 재생되는 경우가 있어, 닫을 때는 time 값을 직접 되감습니다.
        let controller = entity.playAnimation(animation, transitionDuration: 0, startsPaused: true)
        let duration = max(controller.duration, 0.1)
        controller.pause()
        controller.time = duration

        animationController = controller
        isAnimating = true

        animationTask = Task { @MainActor in
            let frameCount = 90
            let frameDuration = duration / Double(frameCount)
            let frameNanoseconds = UInt64(frameDuration * 1_000_000_000)

            for frame in stride(from: frameCount, through: 0, by: -1) {
                guard !Task.isCancelled else { return }

                let progress = Double(frame) / Double(frameCount)
                controller.time = duration * progress
                try? await Task.sleep(nanoseconds: frameNanoseconds)
            }

            controller.pause()
            controller.time = 0
            isOpen = false
            isAnimating = false
        }
    }

    private func configureInputTargets(in entity: Entity) {
        entity.components.set(InputTargetComponent())

        for child in entity.children {
            configureInputTargets(in: child)
        }
    }

    private func firstAvailableAnimation(in entity: Entity) -> AnimationResource? {
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
}

#Preview(windowStyle: .volumetric) {
    // Preview에서도 volumetric window 스타일로 모델 크기와 회전 동작을 확인할 수 있게 합니다.
    BoxVolumeView(payload: BoxPayload(name: "Preview Box"))
}
