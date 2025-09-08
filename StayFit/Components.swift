import SwiftUI

// Reusable card container
struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.black.opacity(0.06)))
    }
}

// Simple title row + accessory
struct CardHeader<Accessory: View>: View {
    let title: String
    let accessory: Accessory
    init(_ title: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title; self.accessory = accessory()
    }
    var body: some View {
        HStack {
            Text(title).font(.system(size: 19, weight: .semibold))
            Spacer()
            accessory
        }
    }
}
//
//  Components.swift
//  StayFit
//
//  Created by Adithya Nalluri on 9/9/25.
//

