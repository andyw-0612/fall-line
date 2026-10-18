import SwiftUI

struct ProductView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedbackModel = AppModel.shared
    @State private var controlBounds: [CGRect] = []
    @State private var journey = ProductJourney()
    let session: CatalogueSession
    @State private var showSettings = false
    @State private var lastCursor = 0
    var onBack: () -> Void

    init(session: CatalogueSession, initialProduct: ShoppingProduct, onBack: @escaping () -> Void) {
        self.session = session; self.onBack = onBack
        _journey = State(initialValue: ProductJourney(initialProduct: initialProduct))
    }

    var body: some View {
        GeometryReader { geometry in
            // Fit the entire composition inside the window, including room for motion.
            let inset = max(64, min(geometry.size.width, geometry.size.height) * 0.10)
            let scale = min(
                (geometry.size.width - inset * 2) / 1524,
                (geometry.size.height - inset * 2) / 1090
            )

            ProductJourneyScene(journey: journey, variation: journey.currentID % ProductCardLayout.variationCount, session: session)
                .offset(
                    x: ProductCardLayout.productCenter.x - journey.camera.x,
                    y: ProductCardLayout.productCenter.y - journey.camera.y
                )
                .scaleEffect(scale * journey.zoom)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background {
                    StartupStyle.background.ignoresSafeArea()
                    ProductBackdrop()
                        .scaleEffect(journey.zoom)
                        .opacity(journey.supportingOpacity)
                        .ignoresSafeArea()
                }
                .clipped()
                .overlay {
                    ProductFeedbackLayer(model: feedbackModel, controlBounds: controlBounds, inputEnabled: !journey.isTransitioning && !showSettings)
                        .opacity(journey.supportingOpacity)
                }
                .coordinateSpace(name: "productGestureSurface")
        }
        .onPreferenceChange(ProductControlBoundsKey.self) { controlBounds = $0 }
        .overlay(alignment: .topLeading) {
            Button("New search", systemImage: "arrow.left", action: onBack)
                .labelStyle(.iconOnly)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black.opacity(0.65))
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.75), in: .circle)
                .buttonStyle(.plain)
                .padding(.leading, 44)
                .padding(.top, 52)
                .opacity(journey.supportingOpacity)
                .disabled(journey.isTransitioning)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) {
            Button("Taste & settings", systemImage: "slider.horizontal.3") { showSettings = true }
            Button(action: nextProduct) {
                Label("Next product", systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 24)
                    .frame(height: 52)
                    .background(.white, in: .capsule)
            }
            .accessibilityHint("Follow the path to the next recommended shoe")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.black.opacity(0.7))
            .buttonStyle(.plain)
            .disabled(journey.isTransitioning || session.isWaiting)
            .opacity(journey.supportingOpacity)
            }
            .padding(.trailing, 44)
            .padding(.top, 52)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
            if session.loading { ProgressView("Finding more shoes · \(session.state.queue.count) ready").controlSize(.small) }
            if let error = session.error {
                HStack { Text(error).lineLimit(2).frame(maxWidth: 440); Button("Retry", action: session.retry); Button("Use local", action: session.useLocal) }
            }
            if session.exhausted { Text("You’ve reached the end of the matching catalogue.") }
            Text("Hold to give feedback · ← previous · → next · Palm rest controls in Input menu")
                .font(.system(size: 12))
                .foregroundStyle(.black.opacity(0.45))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(StartupStyle.background.opacity(0.9), in: .capsule)
                .padding(.bottom, 36)
                .allowsHitTesting(false)
                .opacity(journey.supportingOpacity)
            }
        }
        .sheet(isPresented: $showSettings) { CataloguePanel(session: session) }
        .onAppear {
            lastCursor = session.state.cursor
            feedbackModel.onNextProduct = { nextProduct() }
            feedbackModel.onPreviousProduct = { previousProduct() }
            feedbackModel.onSelection = { session.feedback($0) }
            feedbackModel.onUndoSelection = { session.undoGesture($0) }
        }
        .onChange(of: session.currentPick?.id) {
            guard let product = session.currentProduct else { return }
            feedbackModel.escape()
            journey.next(to: product, direction: session.state.cursor < lastCursor ? -1 : 1, reduceMotion: reduceMotion)
            lastCursor = session.state.cursor
        }
        .onChange(of: journey.isTransitioning) {
            if !journey.isTransitioning, let product = session.currentProduct, product.id != journey.current.product.id {
                journey.next(to: product, direction: session.state.cursor < lastCursor ? -1 : 1, reduceMotion: reduceMotion)
                lastCursor = session.state.cursor
            }
        }
        .onDisappear {
            journey.cancel(); feedbackModel.camera.stop(); feedbackModel.inputAvailable = false
            feedbackModel.onNextProduct = nil; feedbackModel.onPreviousProduct = nil
        }
        .onChange(of: journey.currentID) { feedbackModel.escape() }
        .ignoresSafeArea(.container, edges: .top)
    }

    private func previousProduct() {
        guard !journey.isTransitioning, !showSettings, session.state.cursor > 0 else { return }
        feedbackModel.escape()
        session.previous()
    }

    private func nextProduct() {
        guard !journey.isTransitioning, !session.isWaiting, !showSettings else { return }
        feedbackModel.escape()
        session.next()
    }

}
