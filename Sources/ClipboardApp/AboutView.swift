import SwiftUI

/// Edit these strings to match your public contact details (menu bar → About…).
private enum AboutContact {
    static let authorName = "Michael Mark"
    static let emailAddress = "michaelmark16@gmail.com"
    static let website = URL(string: "https://github.com/MichaelMIL")!
}

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appDisplayName)
                        .font(.title2.weight(.semibold))
                    Text("Version \(AppVersion.string) (\(appBuildVersion))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Menu bar clipboard history, overlay, and favorites.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Section("Author") {
                LabeledContent("Name", value: AboutContact.authorName)
                LabeledContent("Email") {
                    Link(AboutContact.emailAddress, destination: URL(string: "mailto:\(AboutContact.emailAddress)")!)
                }
                LabeledContent("Web") {
                    Link(AboutContact.website.absoluteString, destination: AboutContact.website)
                }
            }

            Section {
                Text("© \(copyrightYear) \(AboutContact.authorName). All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var appDisplayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Clipboard"
    }

    private var appBuildVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "—"
    }

    private var copyrightYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }
}
