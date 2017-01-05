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
    
    func testInitialNotificationIsReceived(){
        datasource = RealmDataSource<Cat>(items: nonEmptyRealm.objects(Cat.self))
        
        let firstEvent = ChangesetProperty(nil)
        let secondEvent = ChangesetProperty(nil)
        
        datasource.mutations().element(at: 0).bind(to: firstEvent).disposeIn(bag)
        datasource.mutations().element(at: 1).bind(to: secondEvent).disposeIn(bag)
        
        expect(firstEvent.value?.change).to(equal(ObservableArrayChange.reset))
        expect(secondEvent.value?.change).to(beNil())
    }
    
    func testInsertEventIsReceived(){
        datasource = RealmDataSource<Cat>(items: emptyRealm.objects(Cat.self))
        
        let secondEvent = ChangesetProperty(nil)
        datasource.mutations().element(at: 1).bind(to: secondEvent).disposeIn(bag)
        
        let thirdEvent = ChangesetProperty(nil)
        datasource.mutations().element(at: 2).bind(to: thirdEvent).disposeIn(bag)
        
        let fourthEvent = ChangesetProperty(nil)
        datasource.mutations().element(at: 3).bind(to: fourthEvent).disposeIn(bag)
        
        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        expect(secondEvent.value?.change).toEventually(equal(ObservableArrayChange.beginBatchEditing), timeout:2)
        expect(thirdEvent.value?.change).toEventually(equal(ObservableArrayChange.inserts([0])))
        expect(fourthEvent.value?.change).toEventually(equal(ObservableArrayChange.endBatchEditing))
    }
    
    func testDeleteEventIsReceived(){
        datasource = RealmDataSource<Cat>(items: nonEmptyRealm.objects(Cat.self))
        
        let secondEvent = ChangesetProperty(nil)
        datasource.mutations().element(at: 1).bind(to: secondEvent).disposeIn(bag)
        
        let thirdEvent = ChangesetProperty(nil)
        datasource.mutations().element(at: 2).bind(to: thirdEvent).disposeIn(bag)
        
        let fourthEvent = ChangesetProperty(nil)
        datasource.mutations().element(at: 3).bind(to: fourthEvent).disposeIn(bag)
        
        try! nonEmptyRealm.write {
            datasource.items().forEach(nonEmptyRealm.delete)
        }
        
        expect(secondEvent.value?.change).toEventually(equal(ObservableArrayChange.beginBatchEditing))
        expect(thirdEvent.value?.change).toEventually(equal(ObservableArrayChange.deletes([0])))
        expect(fourthEvent.value?.change).toEventually(equal(ObservableArrayChange.endBatchEditing))
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

        expect(firstEvent.value?.source).toEventually(beEmpty())

        expect(thirdEvent.value?.source).toEventually(haveCount(1))
        expect(thirdEvent.value?.change).toEventually(equal(ObservableArrayChange.inserts([0])))
    }
    
    func testBasicInsertBindingWhereObserverIsBoundAfterInsertWithoutDelay() {
        datasource = RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self))
        
        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        let firstEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:0).bind(to: firstEvent)
        
        let secondEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:1).bind(to: secondEvent)
        
        
        expect(firstEvent.value?.source).toEventually(haveCount(1), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(secondEvent.value).toEventually(beNil(), timeout: 2)
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
            self.datasource.mutations().element(at:1).bind(to: thirdEvent)
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
        
        expect(firstEvent.value?.source).toEventually(haveCount(1), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value?.change).toEventually(equal(ObservableArrayChange.inserts([1])), timeout: 2)
        expect(thirdEvent.value?.source).toEventually(haveCount(2), timeout: 2)
    }

    func testBasicInsertBindingWhereObserverIsBoundAfterInsertWithoutDelayAndAnItemIsAlreadyAdded() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        try! nonEmptyRealm.write {
            nonEmptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
        }
        
        let firstEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:0).bind(to: firstEvent)
        
        let thirdEvent = ChangesetProperty(nil)
        datasource.mutations().element(at:1).bind(to: thirdEvent)
        
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
            self.datasource.mutations().element(at:1).bind(to: thirdEvent)
        }
        
        expect(firstEvent.value?.source).toEventually(haveCount(2), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value).toEventually(beNil(), timeout: 2)
    }
    
    
    func testBasicDeleteWhereDatasourceIsEmptyWhenObservingAfterwards() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        try! nonEmptyRealm.write {
            datasource.items().forEach(nonEmptyRealm.delete)
        }
        
        let firstEvent = ChangesetProperty(nil)
        let secondEvent = ChangesetProperty(nil)
        
        self.datasource.mutations().element(at:0).bind(to: firstEvent)
        self.datasource.mutations().element(at:1).bind(to: secondEvent)
    
        expect(firstEvent.value?.source).toEventually(haveCount(0), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(secondEvent.value).toEventually(beNil(), timeout: 2)
    }

    func testBasicDeleteWhereDatasourceEmptiesAfterObservingOnSameThread() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        let firstEvent = ChangesetProperty(nil)
        self.datasource.mutations().element(at:0).bind(to: firstEvent)
        let thirdEvent = ChangesetProperty(nil)
        self.datasource.mutations().element(at:2).bind(to: thirdEvent)
        
        
        try! nonEmptyRealm.write {
            datasource.items().forEach(nonEmptyRealm.delete)
        }

        expect(firstEvent.value?.source).toEventually(haveCount(1), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value?.change).toEventually(equal(ObservableArrayChange.deletes([0])))
    }
    
    func testBasicDeleteWhereDatasourceEmptiesAfterObservingBeforehand() {
        datasource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        let firstChangeset = ChangesetProperty(nil)
        self.datasource.mutations().element(at: 0).bind(to: firstChangeset)
        let thirdChangeset = ChangesetProperty(nil)
        self.datasource.mutations().element(at: 2).bind(to: thirdChangeset)
        
        try! nonEmptyRealm.write {
            datasource.items().forEach(nonEmptyRealm.delete)
        }
        
        expect(firstChangeset.value?.source).to(haveCount(1))
        
        expect(thirdChangeset.value?.source).toEventually(haveCount(0))
        expect(thirdChangeset.value?.change).toEventually(equal(ObservableArrayChange.deletes([0])))
    }
    
    func testBasicUpdateWhereDatasourceIsObservingBeforehandAfterDelay() {
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
