import UIKit
import XCTest
import RealmSwift
import ReactiveKit
import Nimble


@testable import HotTakeRealm

/*  
    Realm should provide to us an initial notification containing the fetched results, and then
    provide updates afterwards about any changes.
*/

class RealmNotificationTests: XCTestCase {
    
    var realm: Realm!
    var bag = DisposeBag()
    
    override func setUp() {
        super.setUp()
        
        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString))
    }
    
    override func tearDown() {
        bag.dispose()
        realm = nil
        
        super.tearDown()
    }
    
    func testStartingConditions() {
        expect(self.realm.objects(Cat.self).count).to(equal(0))
    }
    
    func testInsertNotificationWorking(){
        var insertions = 0
        
        try! realm.write {
            realm.add(Cat(value: ["name" : "Mr Catzz"]))
            realm.add(Cat(value: ["name" : "Mr Lolz"]))
        }

        let token = realm.objects(Cat.self).addNotificationBlock { (changeSet:RealmCollectionChange) in
            switch changeSet {
            case .initial(let cats):
                insertions += cats.count
            case .update(_):
                fail("Update should never be called")
            case .error:
                fail("Error should never be called")
            }
        }

        bag.add(disposable: BlockDisposable{token.stop()})
        
        expect(insertions).toEventually(equal(2), timeout: 3)
    }
    
    func testUpdateNotificationWorking(){
        var initialCount = 0
        var inserts = 0
        var updates = 0
        var deletes = 0
        
        let catA = Cat(value: ["name" : "Mr Catzz"])
        let catB = Cat(value: ["name" : "Mr Lolz"])
        try! realm.write {
            realm.add(catA)
            realm.add(catB)
        }
        
        let token = realm.objects(Cat.self).addNotificationBlock { (changeSet:RealmCollectionChange) in
            switch changeSet {
            case .initial(let array):
                initialCount += array.count
            case let .update(_, deletions, insertions, modifications):
                inserts += insertions.count
                deletes += deletions.count
                updates += modifications.count
            case .error:
                fail("Error should never be called")
            }
        }
        
        try! realm.write {
            realm.add(Cat(value: ["name" : "Mr A. Nother"]))
            catA.name = "Renamed cat"
        }
        
        bag.add(disposable: BlockDisposable{token.stop()})
        
        expect(initialCount).toEventually(equal(2), timeout: 3)
        expect(inserts).toEventually(equal(1), timeout: 3)
        expect(updates).toEventually(equal(1), timeout: 3)
        expect(deletes).toEventually(equal(0), timeout: 3)
    }
}
