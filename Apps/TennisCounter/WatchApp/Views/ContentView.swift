//
//  ContentView.swift
//  TennisCounter Watch App
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

struct ContentView: View {

    @State private var showMatch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Tennis Counter")
                    .font(.system(size: 18, weight: .bold))

                NavigationLink(destination: MatchView()) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("Quick Match")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green.opacity(0.8))
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
