//
//  HomeView.swift
//  TennisCounter Watch App
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

struct HomeView: View {
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing:4) {
                    Text("Ralli")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.green)
                        .italic()
                    Text("Tennis Counter")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                NavigationLink(destination: WorkoutFlowView()) {
                    Text(String(localized: "watch_start_workout"))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                    
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
