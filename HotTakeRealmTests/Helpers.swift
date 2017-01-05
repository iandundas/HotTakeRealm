//
//  Helpers.swift
//  HotTakeCore
//
//  Created by Ian Dundas on 30/11/2016.
//  Copyright © 2016 Ian Dundas. All rights reserved.
//

import Foundation
import ReactiveKit
import Bond
import Nimble

typealias ChangesetProperty = ReactiveKit.Property<ObservableArrayEvent<Cat>?>

public func equal(_ expected: ObservableArrayChange?) -> MatcherFunc<ObservableArrayChange?> {
    return MatcherFunc { actualExpression, failureMessage in
        failureMessage.postfixMessage = "equal <\(expected)>"
        
        guard let evaluatedActualValue = try actualExpression.evaluate() else {return false}
        guard let concreteActualValue = evaluatedActualValue, let expectedValue = expected else {
            return evaluatedActualValue == nil && expected == nil // if they're both nil, then alright.
        }
        
        switch (concreteActualValue, expectedValue){
        case (.reset, .reset): return true
        case (.beginBatchEditing, .beginBatchEditing): return true
        case (.endBatchEditing, .endBatchEditing): return true
        case let (.inserts(a), .inserts(b)): return a == b
        case let (.deletes(a), .deletes(b)): return a == b
        case let (.updates(a), .updates(b)): return a == b
        case let (.move(a), .move(b)): return a == b
        default:
            return false
        }
    }
}
