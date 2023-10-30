//
//  ContentView.swift
//  GolfCounter
//
//  Created by 윤재 on 2023/04/20.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    NavigationLink(destination: SingleGameView()) {
                        Text("Single Game")
                            .font(.system(size: 30))
                            .padding()
                    }
                    NavigationLink(destination: ScoreListView()) {
                        Text("Score Board")
                            .font(.system(size: 30))
                            .padding()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

