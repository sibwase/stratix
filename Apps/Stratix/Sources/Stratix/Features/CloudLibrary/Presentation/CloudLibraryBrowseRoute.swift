// CloudLibraryBrowseRoute.swift
// Defines cloud library browse route for the Features / CloudLibrary surface.
//

import Foundation

enum CloudLibraryBrowseRoute: String, Hashable, Sendable {
    case library
    case consoles

    /// Maps legacy persisted destinations onto the current browse-route surface.
    static func normalized(from rawValue: String) -> (route: CloudLibraryBrowseRoute, libraryTabID: String?) {
        if rawValue == LibraryTabID.search || rawValue == "home" {
            return (.library, rawValue == LibraryTabID.search ? LibraryTabID.search : nil)
        }
        return (CloudLibraryBrowseRoute(rawValue: rawValue) ?? .library, nil)
    }
}

extension CloudLibraryBrowseRoute {
    var sideRailNavID: SideRailNavID {
        SideRailNavID(rawValue: rawValue) ?? .library
    }

    var heroBackgroundRoute: CloudLibrarySceneModel.HeroBackgroundRoute {
        CloudLibrarySceneModel.HeroBackgroundRoute(rawValue: rawValue) ?? .library
    }

    /// Maps browse routes onto the app-level route enum used by detail and shell state.
    var appRoute: AppRoute {
        switch self {
        case .library: .library
        case .consoles: .home
        }
    }
}

extension SideRailNavID {
    var browseRoute: CloudLibraryBrowseRoute {
        CloudLibraryBrowseRoute(rawValue: rawValue) ?? .library
    }
}
