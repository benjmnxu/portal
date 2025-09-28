//
//  WindowConfigurator.swift
//  Portal2
//
//  Created by Benjamin Xu on 9/27/25.
//

import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.toolbarStyle = .unifiedCompact
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
