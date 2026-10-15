import SwiftUI

struct AboutView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showCerts = false

    private var stats: [(String, Int)] {
        CertificationType.allCases.map { c in (c.title, store.products.filter { $0.certification == c }.count) }
            .filter { $0.1 > 0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        FolkStripe().clipShape(Capsule())
                        Text("Gust Românesc").font(.title2.weight(.bold))
                        Text("Produse tradiționale, montane, ecologice și cu origine protejată, atestate oficial în România – și drumul până la producător.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("Date") {
                    LabeledContent("Produse", value: store.products.count.formatted())
                    LabeledContent("Producători", value: Set(store.products.map(\.producerId)).count.formatted())
                    LabeledContent("Puncte de lucru", value: store.points.count.formatted())
                    LabeledContent("Județe", value: "\(store.productsByCounty.count)")
                    if let d = store.lastUpdated {
                        LabeledContent("Actualizat", value: d.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        HStack {
                            Label("Actualizează acum", systemImage: "arrow.clockwise")
                            if store.isRefreshing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(store.isRefreshing)
                }
                Section("Pe tipuri de atestat") {
                    ForEach(stats, id: \.0) { s in LabeledContent(s.0, value: s.1.formatted()) }
                    Button("Ce înseamnă fiecare atestat?") { showCerts = true }
                }
                Section("Sursa datelor") {
                    Text("Datele provin din Catalogul Produselor și Activităților Certificate (CPAC), administrat de Agenția pentru Finanțarea Investițiilor Rurale (AFIR). Aplicația nu este afiliată AFIR. Verifică programul și disponibilitatea direct la producător înainte de drum.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link(destination: URL(string: "https://cpac.afir.info/ToateProdusele")!) {
                        Label("cpac.afir.info", systemImage: "safari")
                    }
                }
                Section("Confidențialitate") {
                    Text("Locația ta se folosește doar pe telefon, ca să îți arătăm producătorii din apropiere. Nu o trimitem nicăieri. Favoritele rămân pe dispozitiv.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Despre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gata") { dismiss() } } }
            .sheet(isPresented: $showCerts) { CertificationInfoSheet() }
        }
    }
}
