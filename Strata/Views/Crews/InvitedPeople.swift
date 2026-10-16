import Contacts
import ContactsUI
import MessageUI
import SwiftUI
import UIKit

/// **Who you invited, on the row, before they join** (the owner, 2026-10-15:
/// "inviting should show the invited person on the row with their Apple
/// picture and name"; 2026-10-16: "when I invited someone outside the app
/// their pfp and name didn't pop up on the add row as invited").
///
/// The share sheet never says who a link went to, so nothing could show.
/// Invite now starts from the system's contact picker, which runs outside the
/// app and needs no permission: only the one person chosen comes back, and a
/// text to them is written with the link. Once it is sent they stand at the
/// end of the Today row, faded in a dashed ring, until someone of that name
/// joins the crew, or a week passes. **Kept on this phone only**: their name
/// and picture are never sent anywhere.
nonisolated struct InvitedPerson: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    /// The contact's own picture, small, or nil for their initial.
    let photo: Data?
    let crew: String
    let sentAt: Date

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

@MainActor
@Observable
final class InvitedPeople {
    static let shared = InvitedPeople()
    static let key = "crews.invitedPeople"
    /// A week: past it, an invitation nobody answered is not news.
    static let keepFor: TimeInterval = 7 * 86_400
    static let cap = 12

    private(set) var people: [InvitedPerson] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        people = (defaults.data(forKey: Self.key)).flatMap { try? JSONDecoder().decode([InvitedPerson].self, from: $0) } ?? []
    }

    func add(_ person: InvitedPerson) {
        people.removeAll { $0.name.caseInsensitiveCompare(person.name) == .orderedSame && $0.crew == person.crew }
        people.append(person)
        people = Array(people.suffix(Self.cap))
        save()
    }

    func remove(_ id: UUID) {
        people.removeAll { $0.id == id }
        save()
    }

    /// Still waiting: not past a week, the crew still there, and nobody of
    /// their first name has joined it since the invitation went.
    func waiting(in crews: [Crew], now: Date = Date()) -> [InvitedPerson] {
        Self.waiting(people, in: crews, now: now)
    }

    nonisolated static func waiting(_ people: [InvitedPerson], in crews: [Crew], now: Date) -> [InvitedPerson] {
        people.filter { person in
            guard now.timeIntervalSince(person.sentAt) < keepFor,
                  let crew = crews.first(where: { $0.id.rawValue == person.crew }) else { return false }
            let joined = crew.members.contains {
                $0.joinedAt >= person.sentAt.addingTimeInterval(-60)
                    && $0.firstName.caseInsensitiveCompare(person.firstName) == .orderedSame
            }
            return !joined
        }
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(people), forKey: Self.key)
    }
}

/// **Invite someone**: the contact picker, then a text to them with the link;
/// where the phone cannot text (an iPad, the simulator) or they have no
/// number, the share sheet, as before.
@MainActor
enum InvitePicking {
    private static var helper: Helper?

    static func start(_ crewID: CrewID) {
        let picker = CNContactPickerViewController()
        let helper = Helper(crewID: crewID)
        self.helper = helper
        picker.delegate = helper
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        CrewSharing.present(picker)
    }

    fileprivate static func picked(_ contact: CNContact, crewID: CrewID) {
        let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let photo = contact.thumbnailImageData.flatMap { ShareDerivative.jpeg(from: $0, longEdge: 120) }
        let person = InvitedPerson(id: UUID(), name: name.isEmpty ? "A friend" : name, photo: photo,
                                   crew: crewID.rawValue, sentAt: Date())
        let number = contact.phoneNumbers.first?.value.stringValue
        Task {
            // After the picker has gone: two presentations at once refuse.
            try? await Task.sleep(for: .milliseconds(450))
            guard MFMessageComposeViewController.canSendText(), let number else {
                await CrewSharing.invite(crewID, onSent: { InvitedPeople.shared.add(person) })
                return
            }
            do {
                let url = try await SocialStore.shared.inviteURL(for: crewID)
                let composer = MFMessageComposeViewController()
                let helper = Helper(crewID: crewID)
                helper.person = person
                self.helper = helper
                composer.messageComposeDelegate = helper
                composer.recipients = [number]
                composer.body = "\(CrewSharing.title(for: crewID)) \(url.absoluteString)"
                CrewSharing.present(composer)
            } catch {
                CrewRouter.shared.joinProblem = CrewErrorWords.say(error, while: .inviting)
            }
        }
    }

    private final class Helper: NSObject, CNContactPickerDelegate, MFMessageComposeViewControllerDelegate {
        let crewID: CrewID
        var person: InvitedPerson?

        init(crewID: CrewID) { self.crewID = crewID }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            InvitePicking.picked(contact, crewID: crewID)
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            InvitePicking.picked(contactProperty.contact, crewID: crewID)
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            if result == .sent, let person {
                InvitedPeople.shared.add(person)
                Analytics.shared.signal(.crewInviteSent)
            }
            controller.dismiss(animated: true)
        }
    }
}

/// **Someone invited, waiting to join**: their picture or initial, faded,
/// in the dashed ring the Invite button wears, their first name under it.
struct InvitedHead: View {
    let person: InvitedPerson
    let side: CGFloat
    let inset: CGFloat

    var body: some View {
        VStack(spacing: GridConstants.spacing) {
            ZStack {
                if let data = person.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    AppColors.quietFill
                    Text(String(person.firstName.prefix(1)).uppercased())
                        .font(.system(size: side * 0.4, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }
            .frame(width: side - 8, height: side - 8)
            .clipShape(Circle())
            .opacity(0.6)
            .frame(width: side, height: side)
            .overlay {
                Circle().strokeBorder(AppColors.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            .padding(.horizontal, inset)
            .padding(.top, inset)
            Text(person.firstName)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkTertiary)
                .lineLimit(1)
                .frame(maxWidth: side + inset * 2)
        }
        .contextMenu {
            Button(role: .destructive) { InvitedPeople.shared.remove(person.id) } label: {
                Label("Remove", systemImage: "xmark")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.firstName), invited")
    }
}
