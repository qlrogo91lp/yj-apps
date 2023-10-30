//
//  SIngleGameView.swift
//  GolfCounter Watch App
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
        VStack {
            Text("Hole Type")
                .bold()
                .font(.system(size: 20))
            
            Picker("", selection: $maxHole) {
                ForEach(HoleType.allCases) { type in
                    Text(type.rawValue)
                        .font(.system(size: 30))
                        .tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            .frame(minHeight: 60, maxHeight: 70)
            .padding(.bottom)
            
            NavigationLink(destination: SingleGameCounterView(maxHole: $maxHole)) {
                Text("Confirm")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
    }
}

//#Preview {
//    SingleGameView()
//}
