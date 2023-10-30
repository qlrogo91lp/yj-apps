//
//  SingleGameCounterView.swift
//  GolfCounter
//
//  Created by 윤재 on 10/30/23.
//

import SwiftUI

struct SingleGameCounterView: View {
    @Binding var maxHole: HoleType
    @State var score = Score()
    
    var body: some View {
        let item: String = maxHole.rawValue
        
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Image(systemName: "flag.fill")
                        .imageScale(.large)
                        .foregroundColor(.blue)
                    
                    Text("Par \(item)")
                        .font(.system(size: 40))
                        .bold()
                        .foregroundColor(.blue)
                }
                .padding()
                
                HStack {
                    Button(action: {
                        if(score.current < (Int(item)!)*2) {
                            score.current += 1
                        }
                    }, label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay() {
                                Circle().stroke(.gray, lineWidth: 4)
                            }
                            .overlay() {
                                Image(systemName: "plus")
                                    .imageScale(.large)
                                    .foregroundColor(.gray)
                            }
                    })
                    
                    Spacer()
                    
                    Button(action: {
                        if(score.current > 0) {
                            score.current -= 1
                        }
                    }, label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay() {
                                Circle().stroke(.gray, lineWidth: 4)
                            }
                            .overlay() {
                                Image(systemName: "minus")
                                    .imageScale(.large)
                                    .foregroundColor(.gray)
                            }
                    })
                    
                }
                .padding()
                
                Text("+ \(score.current)")
                    .font(.system(size: 40))
                    .bold()
                    .foregroundColor(.white)
                    .padding(.bottom)
                
                HStack {
                    Button(action: {
                        score.current = 0
                    }, label: {
                        Text("Reset")
                            .font(.system(size: 40))
                            .bold()
                            .foregroundColor(.gray)
                    })
                }
            }.padding(.maximum(80, 80))
        }
        
    }
}

#Preview {
    SingleGameCounterView(maxHole: .constant(.Par5))
}
