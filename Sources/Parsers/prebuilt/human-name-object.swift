import Foundation

extension Prebuilt {
    public struct HumanNameObject: Equatable, Sendable, Hashable, Codable {
        public let fullName: Prebuilt.HumanFullName
        public let nameComponents: Prebuilt.HumanNameComponents?

        public init(
            fullName: HumanFullName,
            nameComponents: HumanNameComponents?
        ) {
            // prefer full name set by components if available
            if let comps = nameComponents {
                self.nameComponents = comps
                self.fullName = comps.fullName
            } else {
                self.nameComponents = nil
                self.fullName = fullName
            }
        }

        public init(
            full_name: String?,
            first_name: String?,
            middle_names: [String]?,
            infix: String?,
            last_name: String?
        ) throws {
            // if name components were provided, try them first
            // if they are nil, this will just return nil
            // they are partially provided, it will try to parse and throw upon failures
            self.nameComponents = try Prebuilt.parseOptionalHumanNameComponents(
                first_name: first_name,
                middle_names: middle_names,
                infix: infix,
                last_name: last_name
            )
            
            if let comps = self.nameComponents {
                self.fullName = comps.fullName
            } else {
                self.fullName = try Prebuilt.HumanFullName(full_name)
            }
        }
    }
}
