//
//  SinglegGameView.swift
//  GolfCounter
//
//  Created by 윤재 on 10/30/23.
//

import SwiftUI

enum HoleType: String, CaseIterable, Identifiable {
    case Par3 = "3"
    case Par4 = "4"
    case Par5 = "5"
    
    var id: String { self.rawValue }
}

struct SingleGameView: View {
    @State private var maxHole = HoleType.Par3
    
    var body: some View {
        NavigationStack {
        
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
            
                VStack {
                    Text("Hole Type")
                        .font(.system(size: 30))
                        .bold()
                        .foregroundColor(.white)
                    
                    
                    Picker("", selection: $maxHole) {
                        ForEach(HoleType.allCases) { type in
                            Text(type.rawValue)
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                    
                    NavigationLink(destination: SingleGameCounterView(maxHole: $maxHole)) {
                        Text("Confirm")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    }
                }
            }
            
        }
    }
}

#Preview {
    SingleGameView()
}
