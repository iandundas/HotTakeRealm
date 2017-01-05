//
//  RealmDataSource.swift
//  ReactiveKitSwappableDatasource
//
//  Created by Ian Dundas on 04/05/2016.
//  Copyright © 2016 IanDundas. All rights reserved.
//

import UIKit
import ReactiveKit
import Bond
import RealmSwift
import HotTakeCore

// Causes compiler crash:
/* extension AnyRealmCollection{
    func items()-> [Element]{
        return filter{_ in true}
    }
}*/

open class RealmDataSource<Item: Object>: DataSourceType where Item: Equatable {

    /* NB: It's important that the Realm collection is already sorted before it's passed to the RealmDataSource:

     > "Note that the order of Results is only guaranteed to stay consistent when the
     > query is sorted. For performance reasons, insertion order is not guaranteed to be preserved.
     > If you need to maintain order of insertion, some solutions are proposed here.
     */

    open func items() -> [Item] {
        return self.collection.filter{_ in true}
    }

    open func mutations() -> Signal1<ObservableArrayEvent<Item>> {
        return Signal1<ObservableArrayEvent<Item>> { observer in
            let bag = DisposeBag()
            

            // Observation started, send the .reset event:
            var initialItems: [Item]? = self.items()
            let source = ObservableArray(initialItems!)
            let event = ObservableArrayEvent<Item>(change: .reset, source: source)
            observer.next(event)
            
            
            let notificationToken = self.collection.addNotificationBlock {(changes: RealmCollectionChange) in
                switch changes {
                    
                case .initial(let realmInitialCollection):
//                    let source = ObservableArray(initialCollection.filter{_ in true})
//                    let event = ObservableArrayEvent<Item>(change: .reset, source: source)
//                    observer.next(event)
                    

                    guard let observerInitialItems = initialItems else {fatalError("Misunderstanding..")}
                    
                    // Realm .initial event clashes with our own. Need to work out if it's any different to the
                    // event we sent observers when they first observed
                    
                
                    initialItems = nil
                    if realmInitialCollection.elementsEqual(observerInitialItems){
                        // If it's the same then it's a non-event - we should suppress it totally
                        break;
                    }
                    else{
                        // If it's different, we need to manually diff Realm's .initial with our own
                        // and provide that diff as the real initial event.
                        let tempCollection = MutableObservableArray(observerInitialItems)
                        let usable = tempCollection.filter { (event: ObservableArrayEvent<Item>) -> Bool in
                            return event.isSignpost || event.affectedCount > 0
                        }.skip(first:1) // reset

                        usable.observeNext(with: observer.next).disposeIn(bag)
                        tempCollection.replace(with: realmInitialCollection.filter {_ in true}, performDiff: true)
                        break;
                    }
                    
//                    }
//                    else {
//                        let insertIndexes = (initialCollection.startIndex ..< initialCollection.endIndex).map {$0}
//                        let changeSet = CollectionChangeset(collection: initialCollection.items(), inserts: insertIndexes, deletes: [], updates: [])
//                        observer.next(changeSet)
//                    }
                    
                    break
                    
                case .update(let updatedCollection, let deletions, let insertions, let modifications):
                    guard deletions.count > 0 || insertions.count > 0 || modifications.count > 0 else {break}

                    let source = ObservableArray(updatedCollection.filter{_ in true})
                    
                    // Begin
                    observer.next(ObservableArrayEvent<Item>(
                        change: .beginBatchEditing,
                        source: source))
                    
                    // in Bond the order is: Insert/ Delete/ Move
                    
                    if insertions.count > 0 {
                        observer.next(ObservableArrayEvent<Item>(
                            change: ObservableArrayChange.inserts(insertions),
                            source: source))
                    }
                    
                    if deletions.count > 0 {
                        observer.next(ObservableArrayEvent<Item>(
                            change: ObservableArrayChange.deletes(deletions),
                            source: source))
                    }
                    
                    if modifications.count > 0 {
                        observer.next(ObservableArrayEvent<Item>(
                            change: ObservableArrayChange.updates(modifications),
                            source: source))
                    }
                    
                    observer.next(ObservableArrayEvent<Item>(change: .endBatchEditing, source: source))
                    
                case .error(let error):
                    // An error occurred while opening the Realm file on the background worker thread
                    fatalError("\(error)")
                }
                
                
//                switch changes {
//                case .Initial(let initialCollection):
//                    
//                    if let initialItems = initialChangeSet?.collection {
//                        initialChangeSet = nil
//                        
//                        // Realm .initial event clashes with our own. Need to work out if it's any different to the
//                        // event we sent observers when they first observed
//                        if initialCollection.elementsEqual(initialItems){
//                            // If it's the same we want to suppress it totally
//                            break;
//                        }
//                        else{
//                            // If it's different, we need to manually diff Realm's .initial with our own
//                            // and provide that diff as the real initial event.
//                            let tempCollection = CollectionProperty(initialItems)
//                            
//                            tempCollection.skip(1).observeNext(observer.next).disposeIn(bag)
//                            tempCollection.replace(initialCollection.items(), performDiff: true)
//                            break;
//                        }
//                    }
//                    else {
//                        let insertIndexes = (initialCollection.startIndex ..< initialCollection.endIndex).map {$0}
//                        let changeSet = CollectionChangeset(collection: initialCollection.items(), inserts: insertIndexes, deletes: [], updates: [])
//                        observer.next(changeSet)
//                    }
//                    
//                case .Update(let updatedCollection, let deletions, let insertions, let modifications):
//                    let changeSet = CollectionChangeset(collection: updatedCollection.items(), inserts: insertions, deletes: deletions, updates: modifications)
//                    observer.next(changeSet)
//
//                case .Error(let error):
//
//                    // An error occurred while opening the Realm file on the background worker thread
//                    fatalError("\(error)")
//                    break
//                }
            }
            
            bag.add(disposable: BlockDisposable{
                notificationToken.stop()
            })
            return bag
        }
    }

    fileprivate let collection: AnyRealmCollection<Item>

    fileprivate let disposeBag = DisposeBag()

    public init<C: RealmCollection>(items: C) where C.Element == Item {
        self.collection = AnyRealmCollection(items)
    }
}

