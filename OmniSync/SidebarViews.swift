import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        List {
            Section("Connection") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.host.isEmpty ? "No host set" : viewModel.host)
                        .font(.body.weight(.semibold))
                    Text(viewModel.username.isEmpty ? "Username not set" : viewModel.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !viewModel.remotePath.isEmpty {
                    Text(viewModel.remotePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Actions") {
                NavigationLink {
                    FiltersDetailView(viewModel: viewModel)
                } label: {
                    Label("File Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct FiltersDetailView: View {
    @ObservedObject var viewModel: SyncViewModel

    var body: some View {
        Form {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(FileFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.menu)

            Text(viewModel.selectedFilter.example)
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.selectedFilter == .custom {
                Section("Custom patterns") {
                    TextField("Comma separated (e.g. *.mp4,*.jpg)", text: $viewModel.customFilterPatterns)
                }
            }
        }
        .padding()
        .frame(minWidth: 320)
    }
}
