//
//  String+Random.swift
//  Webber
//
//  Created by Mihael Isaev on 11.02.2021.
//

import Foundation
import Vapor

extension String {
    static func shuffledAlphabet(_ length: Int, upperLetters: Bool? = nil, lowerLetters: Bool? = nil, digits: Bool? = nil, specialCharacters: Bool? = nil) -> String {
        var letters = ""
        if digits == true {
            letters.append("0123456789")
        }
        if upperLetters == true {
            letters.append("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        }
        if lowerLetters == true {
            letters.append("abcdefghijklmnopqrstuvwxyz")
        }
        if specialCharacters == true {
            letters.append("!@#$%&()=.")
        }
        if letters.count == 0 {
            assert(letters.count == 0, "Unable to generate random string")
        }
        var randomString = ""
        for _ in 0...length - 1 {
            let random = [UInt32].random(count: 1)[0]
            let rand = random % UInt32(letters.count)
            let ind = Int(rand)
            let character = letters[letters.index(letters.startIndex, offsetBy: ind)]
            randomString.append(character)
        }
        return randomString
    }
    
    static func shuffledNumber(_ length: Int) -> String {
        let letters = "0123456789"
        var randomString = ""
        for _ in 0...length - 1 {
            let random = [UInt32].random(count: 1)[0]
            let rand = random % UInt32(letters.count)
            let ind = Int(rand)
            let character = letters[letters.index(letters.startIndex, offsetBy: ind)]
            randomString.append(character)
        }
        return randomString
    }
}
