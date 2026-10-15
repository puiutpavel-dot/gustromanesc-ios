import SwiftUI
import CoreLocation

// MARK: - Paletă

enum Theme {
    static let accent = Color(red: 0.70, green: 0.16, blue: 0.20)      // roșu de ie
    static let ochre = Color(red: 0.86, green: 0.62, blue: 0.20)
    static let forest = Color(red: 0.16, green: 0.36, blue: 0.27)
    static let paper = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1)
                                      : UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(red: 0.16, green: 0.15, blue: 0.13, alpha: 1) : .white
    })
}

/// Bandă cu motiv tradițional (romburi), desenată vectorial.
struct FolkStripe: View {
    var color: Color = Theme.accent
    var height: CGFloat = 10
    var body: some View {
        Canvas { ctx, size in
            let w = height * 1.4
            var x: CGFloat = 0
            var i = 0
            while x < size.width + w {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height / 2))
                p.addLine(to: CGPoint(x: x + w / 2, y: 0))
                p.addLine(to: CGPoint(x: x + w, y: size.height / 2))
                p.addLine(to: CGPoint(x: x + w / 2, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(i % 2 == 0 ? color : Theme.ochre))
                x += w
                i += 1
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Insigne

struct CategoryIcon: View {
    let category: ProductCategory
    var size: CGFloat = 44
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(category.color.gradient)
            .frame(width: size, height: size)
            .overlay(Image(systemName: category.symbol).font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(.white))
            .accessibilityLabel(category.title)
    }
}

struct Chip: View {
    let title: String
    var symbol: String? = nil
    var color: Color = .secondary
    var filled = false
    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(title).lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 9).padding(.vertical, 5)
        .foregroundStyle(filled ? .white : color)
        .background(Capsule().fill(filled ? color : color.opacity(0.13)))
    }
}

struct RatingView: View {
    let rating: Double
    var compact = false
    var body: some View {
        if rating > 0 {
            HStack(spacing: 2) {
                if compact {
                    Image(systemName: "star.fill").foregroundStyle(Theme.ochre)
                    Text(rating, format: .number.precision(.fractionLength(1)))
                } else {
                    ForEach(0..<5, id: \.self) { i in
                        let v = rating - Double(i)
                        Image(systemName: v >= 0.75 ? "star.fill" : (v >= 0.25 ? "star.leadinghalf.filled" : "star"))
                            .foregroundStyle(Theme.ochre)
                    }
                    Text(rating, format: .number.precision(.fractionLength(2))).foregroundStyle(.secondary).padding(.leading, 4)
                }
            }
            .font(compact ? .caption.weight(.semibold) : .subheadline)
            .accessibilityLabel("Rating \(rating.formatted(.number.precision(.fractionLength(1)))) din 5")
        }
    }
}

// MARK: - Rând de produs

struct ProductRow: View {
    let product: Product
    var distance: CLLocationDistance? = nil
    @Environment(Favorites.self) private var favorites

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CategoryIcon(category: product.category)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(product.name).font(.headline).lineLimit(2)
                    Spacer(minLength: 4)
                    if favorites.contains(product) {
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(Theme.accent)
                    }
                }
                Text(product.producerName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    Label("\(product.locality), \(product.county)", systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                    if let distance {
                        Text("·")
                        Text(Geo.formattedDistance(distance)).fontWeight(.semibold).foregroundStyle(Theme.accent)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Chip(title: product.certification.shortTitle, symbol: product.certification.symbol, color: product.certification.color)
                    RatingView(rating: product.rating, compact: true)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Card orizontal (pentru caruselele de pe ecranul principal).
struct ProductCard: View {
    let product: Product
    var distance: CLLocationDistance? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CategoryIcon(category: product.category, size: 36)
                Spacer()
                if let distance {
                    Text(Geo.formattedDistance(distance))
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                } else {
                    RatingView(rating: product.rating, compact: true)
                }
            }
            Text(product.name).font(.subheadline.weight(.semibold)).lineLimit(2, reservesSpace: true)
                .foregroundStyle(.primary)
            Text("\(product.locality), \(product.county)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(12)
        .frame(width: 180, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.bold))
            if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Meniu „Navighează” – alegi aplicația.
struct DirectionsMenu<LabelView: View>: View {
    let coordinate: CLLocationCoordinate2D
    let name: String
    @ViewBuilder var label: () -> LabelView

    var body: some View {
        Menu {
            Section("Navighează cu") {
                ForEach(NavigationApp.allCases) { app in
                    Button { app.open(to: coordinate, name: name) } label: { Label(app.title, systemImage: app.symbol) }
                }
            }
        } label: { label() }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}
