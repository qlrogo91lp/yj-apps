//
//  ContentView.swift
//  GolfCounter Watch App
//
//  Created by 윤재 on 2023/04/20.
//

import SwiftUI

enum HoleType: String, CaseIterable, Identifiable {
    case Par3 = "3"
    case Par4 = "4"
    case Par5 = "5"
    
    var id: String { self.rawValue }
}

struct ContentView: View {
    @State private var maxHole = HoleType.Par3
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("홀 타입", selection: $maxHole) {
                    ForEach(HoleType.allCases) { type in
                        Text(type.rawValue)
                            .font(.system(size: 25))
                            .tag(type)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 80)
                .padding()
                
                NavigationLink(destination: ScoreView(maxHole: $maxHole)) {
                    Text("확인")
                        .font(.system(size: 20))
                        .bold()
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
    }
}
