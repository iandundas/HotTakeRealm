//
//  RealmDatasourceTests.swift
//  ReactiveKitSwappableDatasource
//
//  Created by Ian Dundas on 05/06/2016.
//  Copyright © 2016 IanDundas. All rights reserved.
//

import UIKit
import XCTest
import RealmSwift
import ReactiveKit
import Nimble
import HotTakeCore
import Bond
@testable import HotTakeRealm

class RealmDatasourceTests: XCTestCase {

    var emptyRealm: Realm!
    var nonEmptyRealm: Realm!
    
    var bag: DisposeBag!
    
    var datasource: RealmDataSource<Cat>!
    
    override func setUp() {
        super.setUp()
        bag = DisposeBag()
        
        nonEmptyRealm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        emptyRealm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        
        try! nonEmptyRealm.write {
            nonEmptyRealm.add(Cat(value: ["name" : "Cat A", "miceEaten": 0]))
        }
    }
    
    override func tearDown() {
        bag.dispose()
        
        emptyRealm = nil
        nonEmptyRealm = nil
        
        datasource = nil
        super.tearDown()
    }

    func testBasicInsertBindingWhereObserverIsBoundBeforeInsert() {
        datasource = RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self))

        let firstEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:0).bind(to: firstEvent)
        
        let thirdEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:2).bind(to: thirdEvent)
        
        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        expect(firstEvent.value?.source).toEventually(haveCount(1), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value?.source).toEventually(beNil(), timeout: 2)
    }
    
    func testBasicInsertBindingWhereObserverIsBoundAfterInsertWithoutDelay() {
        datasource = RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self))
        
        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        let firstEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:0).bind(to: firstEvent)
        
        let thirdEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:2).bind(to: thirdEvent)
        
        
        expect(firstEvent.value?.source).toEventually(haveCount(1), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value).toEventually(beNil(), timeout: 2)
    }

    func testBasicInsertBindingWhereObserverIsBoundAfterInsertWithADelay() {
        datasource = RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self))
        
        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        let firstEvent = ChangesetProperty(nil)
        let thirdEvent = ChangesetProperty(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.datasource.mutations().element(at:0).bind(to: firstEvent)
            self.datasource.mutations().element(at:2).bind(to: thirdEvent)
        }
        
        expect(firstEvent.value?.source).toEventually(haveCount(1), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value).toEventually(beNil(), timeout: 2)
    }
    
    
    
    func testBasicInsertBindingWhereObserverIsBoundBeforeInsertAndAnItemIsAlreadyAdded() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        let firstEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:0).bind(to: firstEvent)
        
        let thirdEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:2).bind(to: thirdEvent)
        
        try! nonEmptyRealm.write {
            nonEmptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        expect(firstEvent.value?.source).toEventually(haveCount(2), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value?.source).toEventually(beNil(), timeout: 2)
    }
    
    func testBasicInsertBindingWhereObserverIsBoundAfterInsertWithoutDelayAndAnItemIsAlreadyAdded() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        try! nonEmptyRealm.write {
            nonEmptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        let firstEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:0).bind(to: firstEvent)
        
        let thirdEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:2).bind(to: thirdEvent)
        
        expect(firstEvent.value?.source).toEventually(haveCount(2), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value).toEventually(beNil(), timeout: 2)
    }
    
    
    func testBasicInsertBindingWhereObserverIsBoundAfterInsertWithADelayAndAnItemIsAlreadyAdded() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        try! nonEmptyRealm.write {
            nonEmptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        let firstEvent = ChangesetProperty(nil)
        let thirdEvent = ChangesetProperty(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.datasource.mutations().element(at:0).bind(to: firstEvent)
            self.datasource.mutations().element(at:2).bind(to: thirdEvent)
        }
        
        expect(firstEvent.value?.source).toEventually(haveCount(2), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value).toEventually(beNil(), timeout: 2)
    }
    
    
    func testBasicDeleteWhereColletionIsEmptyWhenObservingAfterwards() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        try! nonEmptyRealm.write {
            datasource.items().forEach(nonEmptyRealm.delete)
        }
        
        let firstEvent = ChangesetProperty(nil)
        let thirdEvent = ChangesetProperty(nil)
        
        self.datasource.mutations().element(at:0).bind(to: firstEvent)
        self.datasource.mutations().element(at:2).bind(to: thirdEvent)
    
        expect(firstEvent.value?.source).toEventually(haveCount(0), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value).toEventually(beNil(), timeout: 2)
    }

    func testBasicDeleteWhereColletionEmptiesAfterObservingOnSameThread() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        let firstEvent = ChangesetProperty(nil)
        self.datasource.mutations().element(at:0).bind(to: firstEvent)
        let thirdEvent = ChangesetProperty(nil)
        self.datasource.mutations().element(at:2).bind(to: thirdEvent)
        
        
        try! nonEmptyRealm.write {
            datasource.items().forEach(nonEmptyRealm.delete)
        }

        expect(firstEvent.value?.source).toEventually(haveCount(0), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value?.change).toEventually(beNil())
    }
    
    
    func testBasicUpdateWhereCollectionIsObservingBeforehandAfterDelay() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        let firstEvent = ChangesetProperty(nil)
        self.datasource.mutations().element(at:0).bind(to: firstEvent)
        let thirdEvent = ChangesetProperty(nil)
        self.datasource.mutations().element(at:2).bind(to: thirdEvent)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let item = self.datasource.items()[0]
            try! self.nonEmptyRealm.write {
                item.name = "new name"
            }
        }
        
        expect(firstEvent.value?.source).toEventually(haveCount(1), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))

        expect(thirdEvent.value?.source).toEventually(haveCount(1), timeout: 2)
        expect(thirdEvent.value?.change).to(equal(ObservableArrayChange.updates([0])))

    }
    
}
