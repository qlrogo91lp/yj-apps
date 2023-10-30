//
//  ContentView.swift
//  GolfCounter Watch App
//
//  Created by 윤재 on 2023/04/20.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        NavigationStack {
            NavigationLink(destination: SingleGameView()) {
                Text("Single Game")
            }
            NavigationLink(destination: ScoreListView()) {
                Text("Score Board")
            }
        }
    }
}

#Preview {
    ContentView()
}
