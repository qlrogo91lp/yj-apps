//
//  SingleGameCounterView.swift
//  GolfCounter Watch App
//
//  Created by 윤재 on 10/30/23.
//

import SwiftUI

struct SingleGameCounterView: View {
    @Binding var maxHole: HoleType
    @State var score = Score()
    
    var body: some View {
        let item: String = maxHole.rawValue

        VStack {
            HStack {
                Spacer()
                
                Image(systemName: "flag.fill")
                    .imageScale(.medium)
                    .foregroundColor(.blue)
                
                Text("Par \(item)")
                    .font(.system(size: 25))
                    .bold()
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("+ \(score.current)")
                    .font(.system(size: 25))
                    .bold()
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack {
                Spacer()
                
                Button(action: {
                    if(score.current < (Int(item)!)*2) {
                        score.current += 1
                    }
                }, label: {
                    Circle()
                        .fill(Color.white)
                        .frame(minWidth: 60, idealWidth: 70, minHeight: 60, idealHeight: 70)
                        .overlay() {
                            Circle().stroke(.gray, lineWidth: 4)
                        }
                        .overlay() {
                            Image(systemName: "plus")
                                .imageScale(.large)
                                .foregroundColor(.gray)
                        }
                }).buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: {
                    if(score.current > 0) {
                        score.current -= 1
                    }
                }, label: {
                    Circle()
                        .fill(Color.white)
                        .frame(minWidth: 60, idealWidth: 70, minHeight: 60, idealHeight: 70)
                        .overlay() {
                            Circle().stroke(.gray, lineWidth: 4)
                        }
                        .overlay() {
                            Image(systemName: "minus")
                                .imageScale(.large)
                                .foregroundColor(.gray)
                        }
                }).buttonStyle(PlainButtonStyle())
                
                Spacer()
            }.padding(.bottom)
            
            HStack {
                Button(action: {
                    score.current = 0
                }, label: {
                    Text("Reset")
                        .font(.system(size: 20))
                        .bold()
                        .foregroundColor(.gray)
                })
            }
        }
    }
}

//#Preview {
//    SingleGameCounterView(maxHole: .constant(.Par5))
//}
