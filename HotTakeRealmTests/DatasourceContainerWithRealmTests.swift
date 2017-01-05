//
//  ContainerTests.swift
//  ReactiveKitSwappableDatasource
//
//  Created by Ian Dundas on 15/05/2016.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
import ReactiveKit
import Nimble
import RealmSwift
import HotTakeCore
import Bond

@testable import HotTakeRealm

class ContainerWithRealmTests: XCTestCase {
    
    var emptyRealm: Realm!
    var nonEmptyRealm: Realm!
    
    var disposeBag = DisposeBag()
    
    var container: Container<Cat>!
    
    override func setUp() {
        super.setUp()
        
        nonEmptyRealm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        emptyRealm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
        
        try! nonEmptyRealm.write {
            nonEmptyRealm.add(Cat(value: ["name" : "Cat A", "miceEaten": 0]))
            nonEmptyRealm.add(Cat(value: ["name" : "Cat D", "miceEaten": 3]))
            nonEmptyRealm.add(Cat(value: ["name" : "Cat M", "miceEaten": 5]))
            nonEmptyRealm.add(Cat(value: ["name" : "Cat Z", "miceEaten": 100]))
        }
    }
    
    override func tearDown() {
        disposeBag.dispose()
        
        emptyRealm = nil
        nonEmptyRealm = nil
        
        container = nil
        
        super.tearDown()
    }
    
    func testReceiveOnlyOneResetEventWhenNoMutationPerformed(){
        container = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self)).encloseInContainer()
        
        let firstEvent = ChangesetProperty(nil)
        container.collection.element(at: 0).bind(to: firstEvent)
        
        let secondEvent = ChangesetProperty(nil)
        container.collection.element(at: 1).bind(to: secondEvent)
        
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        expect(secondEvent.value).toEventually(beNil())
    }
    
    func testBasicInsertBindingWhereObserverIsBoundBeforeInsert() {
        container = RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self)).encloseInContainer()
        
        let firstEvent = ChangesetProperty(nil)
        container.collection.element(at: 0).bind(to: firstEvent)
        
        let thirdEvent = ChangesetProperty(nil)
        container.collection.element(at: 2).bind(to: thirdEvent)
        
        expect(firstEvent.value?.source).to(haveCount(0))
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
            emptyRealm.add(Cat(value: ["name" : "Mr Lolz"]))
        }

        expect(thirdEvent.value?.source).toEventually(haveCount(2), timeout: 2)
        expect(thirdEvent.value?.change).to(equal(ObservableArrayChange.inserts([0,1])))
    }
    
    func testBasicInsertBindingWhereObserverIsBoundAfterInsertWithoutDelay() {
        container = RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self)).encloseInContainer()

        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
            emptyRealm.add(Cat(value: ["name" : "Mr Lolz"]))
        }

        let firstEvent = ChangesetProperty(nil)
        container.collection.element(at: 0).bind(to: firstEvent)
        
        expect(firstEvent.value?.source).toEventually(haveCount(2), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))

        let thirdEvent = ChangesetProperty(nil)
        container.collection.element(at: 2).bind(to: thirdEvent)
        
        expect(thirdEvent.value).toEventually(beNil())
    }
    
    func testBasicInsertBindingWhereObserverIsBoundAfterInsertWithADelay() {
        container = RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self)).encloseInContainer()
        
        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Cow"]))
            emptyRealm.add(Cat(value: ["name" : "Mr Lolz"]))
        }

        let firstEvent = ChangesetProperty(nil)
        let thirdEvent = ChangesetProperty(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.container.collection.element(at: 0).bind(to: firstEvent)
            self.container.collection.element(at: 1).bind(to: thirdEvent)
        }
        
        expect(firstEvent.value?.source).toEventually(haveCount(2), timeout: 2)
        expect(firstEvent.value?.change).toEventually(equal(ObservableArrayChange.reset))
        
        expect(thirdEvent.value?.source).toEventually(beNil(), timeout: 2)
    }    
    
    /* Test it sends a single event containing 0 insert, 0 update, 0 delete when initially an empty container */
    func testInitialSubscriptionSendsASingleCurrentStateEventWhenInitiallyEmpty(){
        container = RealmDataSource<Cat>(items: emptyRealm.objects(Cat.self)).encloseInContainer()
        
        let firstEvent = ChangesetProperty(nil)
        let secondEvent = ChangesetProperty(nil)
        
        container.collection.element(at: 0).bind(to: firstEvent)
        container.collection.element(at: 1).bind(to: secondEvent)
        
        expect(firstEvent.value?.change).to(equal(ObservableArrayChange.reset))
        expect(firstEvent.value?.dataSource.array).to(equal([Cat]()))
        
        expect(secondEvent.value?.change).to(beNil())
    }
    
    
    /* Test it sends an event containing 0 insert, 0 update, 0 delete when initially non-empty container */
    func testInitialSubscriptionSendsASingleCurrentStateEventWhenInitiallyNonEmpty(){
        
        container = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self)).encloseInContainer()
        
        let firstEvent = ChangesetProperty(nil)
        let secondEvent = ChangesetProperty(nil)
        
        container.collection.element(at: 0).bind(to: firstEvent)
        container.collection.element(at: 1).bind(to: secondEvent)
        
        expect(firstEvent.value?.change).to(equal(ObservableArrayChange.reset))
        expect(firstEvent.value?.dataSource.array).to(haveCount(4))
        expect(secondEvent.value?.change).to(beNil())
    }
    
    func testReplacingEmptyDatasourceWithAnotherEmptyDatasourceProducedNoUpdateSignals(){
        
        let emptyRealmDataSource = RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self))
        let emptyManualDataSource = ManualDataSource(items: [Cat]())
        container = emptyRealmDataSource.encloseInContainer()
        
        let firstEvent = ChangesetProperty(nil)
        let secondEvent = ChangesetProperty(nil)
        
        container.collection.element(at: 0).bind(to: firstEvent)
        container.collection.element(at: 1).bind(to: secondEvent)
        
        // replace with another, identical datasource:
        container.datasource = emptyManualDataSource.eraseType()
        
        expect(firstEvent.value?.change).to(equal(ObservableArrayChange.reset))
        expect(firstEvent.value?.dataSource.array).to(haveCount(0))
        
        expect(secondEvent.value?.change).to(beNil())
    }
    
    func testReplacingEmptyDatasourceWithAnotherEmptyDatasourceAndAddingItemsToInitialDataSourceProducesNoUpdateSignals(){
        
        let emptyRealmDataSource = AnyDataSource(RealmDataSource<Cat>(items:emptyRealm.objects(Cat.self)))
        let emptyManualDataSource = AnyDataSource(ManualDataSource(items: [Cat]()))
        
        var observeCallCount = 0
        
        container = Container(datasource: emptyRealmDataSource)
        container.collection
            .observeNext { changes in
                observeCallCount += 1
            }.disposeIn(disposeBag)
        
        container.datasource = emptyManualDataSource
        
        try! emptyRealm.write {
            emptyRealm.add(Cat(value: ["name" : "Mr Catzz"]))
        }
    
        // expect only to have the initial insert changeset (when first binded) and not the subsequent insert.
        expect(observeCallCount).toEventually(equal(1), timeout: 3)
        
    }
    
    func testReplacingNonEmptyDatasourceWithAnIdenticalNonEmptyDatasourceProducedNoUpdateSignals(){
        
        let nonemptyRealmDataSourceA = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        
        container = nonemptyRealmDataSourceA.encloseInContainer()
        
        var observeCallCount = 0
        
        container.collection
            .observeNext { changes in
                observeCallCount += 1
            }.disposeIn(disposeBag)
        
        // replace with another, identical datasource:
        let nonemptyRealmDataSourceB = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self))
        container.datasource = nonemptyRealmDataSourceB.eraseType()
        
        // important because second one can be mistaken for an .Initial event (0,0,0) and we don't want 2x .Initial events.
        // i.e. expect only to have the initial insert changeset (when first binded) and not the subsequent insert.
        expect(observeCallCount).toEventually(equal(1), timeout: 3)
    }
    
    func testReplacingNonEmptyDatasourceWithAnEmptyDatasourceProducesCorrectDeleteSignals(){
        // contains 4 items
        container = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self)).encloseInContainer()
        
        let firstChangeset = ChangesetProperty(nil)
        container.collection.element(at: 0).bind(to: firstChangeset)
        let thirdChangeset = ChangesetProperty(nil)
        container.collection.element(at: 2).bind(to: thirdChangeset)
        
        expect(firstChangeset.value?.source).to(haveCount(4))
        
        // Contains 0 items
        let emptyManualDataSource = AnyDataSource(ManualDataSource(items: [Cat]()))
        container.datasource = emptyManualDataSource
        
        // expect only to have the initial insert changeset (when first binded) and not the subsequent insert.
        expect(thirdChangeset.value?.source).to(haveCount(0))
        expect(thirdChangeset.value?.change).to(equal(ObservableArrayChange.deletes([0,1,2,3])))
    }
    
    func testReplacingEmptyDatasourceWithANonEmptyDatasourceProducesCorrectInsertSignals(){
        
        // contains 0 items
        container = ManualDataSource(items: [Cat]()).encloseInContainer()
        
        let firstChangeset = ChangesetProperty(nil)
        container.collection.element(at: 0).bind(to: firstChangeset)
        let secondChangeset = ChangesetProperty(nil)
        container.collection.element(at: 1).bind(to: secondChangeset)
        let thirdChangeset = ChangesetProperty(nil)
        container.collection.element(at: 2).bind(to: thirdChangeset)
        let fourthChangeset = ChangesetProperty(nil)
        container.collection.element(at: 3).bind(to: fourthChangeset)
        let fifthChangeset = ChangesetProperty(nil)
        container.collection.element(at: 4).bind(to: fifthChangeset)
        let sixthChangeset = ChangesetProperty(nil)
        container.collection.element(at: 5).bind(to: sixthChangeset)
        
        
        // replace with a datasource containing 4 items:
        let nonEmptyRealmDataSource = RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self)).eraseType()
        container.datasource = nonEmptyRealmDataSource
        
        // expect only to have the initial insert changeset (when first binded) and not the subsequent insert.
        expect(firstChangeset.value?.change).to(equal(ObservableArrayChange.reset))
        expect(secondChangeset.value?.change).to(equal(ObservableArrayChange.beginBatchEditing))
        expect(thirdChangeset.value?.dataSource.array).to(haveCount(4))
        expect(thirdChangeset.value?.change).to(equal(ObservableArrayChange.deletes([]))) // TODO non-optimal, but no ideal way to filter these yet
        
        expect(fourthChangeset.value?.change).to(equal(ObservableArrayChange.inserts([0,1,2,3])))
        expect(fifthChangeset.value?.change).to(equal(ObservableArrayChange.endBatchEditing))
        expect(sixthChangeset.value?.change).to(beNil())
    }
    

    func testReplacingNonEmptyDatasourceWithAnotherNonEmptyDatasourceContainingSomeDifferentItemsProducesCorrectMutationSignals(){
        
        let dataSourceA = AnyDataSource(RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self).filter("miceEaten < 5"))) // 2 items (0, 3)
        let dataSourceB = AnyDataSource(RealmDataSource<Cat>(items:nonEmptyRealm.objects(Cat.self).filter("miceEaten > 0"))) // 3 items (   3, 5, 100)
        container = Container(datasource: dataSourceA)
        
        
        let firstChangeset = ChangesetProperty(nil)
        container.collection.element(at: 0).bind(to: firstChangeset)
        let thirdChangeset = ChangesetProperty(nil)
        container.collection.element(at: 2).bind(to: thirdChangeset)
        let fourthChangeset = ChangesetProperty(nil)
        container.collection.element(at: 3).bind(to: fourthChangeset)
        
        expect(firstChangeset.value?.change).to(equal(ObservableArrayChange.reset))
        expect(firstChangeset.value?.source).to(haveCount(2))

        container.datasource = dataSourceB
        
        expect(thirdChangeset.value?.change).to(equal(ObservableArrayChange.deletes([0])))
        expect(fourthChangeset.value?.change).to(equal(ObservableArrayChange.inserts([1,2])))
    }
    
}
