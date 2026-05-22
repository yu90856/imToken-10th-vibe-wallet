import SwiftUI
import UIKit

/// Bitrefill 商品縮圖（API image 或官方 CDN `cdn.bitrefill.com/primg/...`）
struct BitrefillProductImageView: View {
    let productId: String
    var imageURL: String?
    var size: CGFloat = 52
    var cornerRadius: CGFloat = 10

    @Environment(\.colorScheme) private var colorScheme
    @State private var loadedImage: UIImage?
    @State private var activeIndex = 0
    @State private var isLoading = false

    private var candidates: [URL] {
        BitrefillProductImageURLs.candidateURLs(productId: productId, apiImage: imageURL)
    }

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else if isLoading, !candidates.isEmpty {
                ProgressView()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.08), lineWidth: 1)
        )
        .task(id: taskKey) {
            await loadImage()
        }
    }

    private var taskKey: String {
        "\(productId)|\(imageURL ?? "")"
    }

    @MainActor
    private func loadImage() async {
        loadedImage = nil
        activeIndex = 0
        isLoading = !candidates.isEmpty

        var index = 0
        while index < candidates.count {
            let url = candidates[index]
            if let image = await Self.fetchImage(from: url) {
                loadedImage = image
                isLoading = false
                return
            }
            index += 1
        }
        isLoading = false
    }

    private static func fetchImage(from url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 12
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.stickyNoteFill(for: colorScheme))
            Image(systemName: "giftcard.fill")
                .font(.system(size: size * 0.38))
                .foregroundStyle(AppTheme.primary.opacity(0.55))
        }
    }
}
