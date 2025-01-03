/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Network utility functions to simulate pushing and pulling data, as well as process a mock server response.
*/

import Foundation
import HealthKit

class Network {
    
    // MARK: - Sending Data
    
    class func push(addedSamples: [HKObject]? = nil, deletedSamples: [HKDeletedObject]? = nil) {
        if let samples = addedSamples, !samples.isEmpty {
            pushAddedSamples(samples)
        }
        
        if let deletedSamples = deletedSamples, !deletedSamples.isEmpty {
            pushDeletedSamples(deletedSamples)
        }
    }
    
    class func pushAddedSamples(_ objects: [HKObject]) {
        var statusDictionary: [String: Int] = [:]
        for object in objects {
            guard let sample = object as? HKSample else {
                print("We don't support pushing non-sample objects at this time!")
                
                return
            }
            
            let identifier = sample.sampleType.identifier
            
            if let value = statusDictionary[identifier] {
                statusDictionary[identifier] = value + 1
            } else {
                statusDictionary[identifier] = 1
            }
        }
        
        print("Pushing \(objects.count) new samples to server!")
        print("Samples:", statusDictionary)
    }
    
    class func pushDeletedSamples(_ samples: [HKDeletedObject]) {
        print("Pushing \(samples.count) deleted samples to server!")
        print("Samples:", samples)
    }
}
