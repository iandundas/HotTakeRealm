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
        
        try! realm.write {
            realm.add(Cat(value: ["name" : "Mr Catzz"]))
            realm.add(Cat(value: ["name" : "Mr Lolz"]))
        }
        
        expect(insertions).toEventually(equal(2), timeout: 3)
    }
}
