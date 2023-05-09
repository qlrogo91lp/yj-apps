//
//  ContentView.swift
//  GolfCounter
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
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Picker("Hole Type", selection: $maxHole) {
                        ForEach(HoleType.allCases) { type in
                            Text(type.rawValue)
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    HStack {
                        Text("홀 타입 : ")
                            .font(.system(size: 30))
                            .bold()
                            .foregroundColor(.white)
                            
                        Text("\(maxHole.rawValue)")
                            .font(.system(size: 30))
                            .bold()
                            .foregroundColor(.gray)
                    }.padding(.bottom)
        
                    
                    NavigationLink(destination: ScoreView(maxHole: $maxHole)) {
                        Text("확인")
                            .font(.system(size: 30))
                            .bold()
                            .foregroundColor(.blue)
                    }
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
