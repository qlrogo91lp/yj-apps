import Foundation
import SwiftData

@Model
class SetRecord {
    var myGames: Int = 0
    var yourGames: Int = 0
    var setNumber: Int = 0

    init(myGames: Int, yourGames: Int, setNumber: Int) {
        self.myGames = myGames
        self.yourGames = yourGames
        self.setNumber = setNumber
    }
}
