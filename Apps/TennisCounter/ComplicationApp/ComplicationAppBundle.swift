//
//  ComplicationAppBundle.swift
//  ComplicationApp
//
//  Created by 윤재 on 11/6/25.
//

import SwiftUI
import WidgetKit

@main
struct ComplicationAppBundle: WidgetBundle {
    var body: some Widget {
        ComplicationApp()
        ComplicationAppControl()
    }
}
