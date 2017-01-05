//
//  EnumEnhancerTests.swift
//  EnumEnhancerTests
//
//  Created by David Sweeris on 2016/01/19.
//  Copyright © 2016 David Sweeris. All rights reserved.
//

import XCTest
@testable import EnumEnhancer
protocol Initable { init() }
struct Foo : Initable {
    let value = "bar"
}

enum RawValueEnum : Int, EnumeratesCasesAndLabels {
    // Swift's type inference gets a bit tripped up here... This is the recommended way to solve it.
    static let enhancer:EnumEnhancer<RawValueEnum> = EnhancedGenerator {
        // `$0` is a RawValueEnum?
        switch $0 {
        case .none: $0 = .zero
        case .some(let theCase):
            switch theCase {
            case .zero: $0 = .one
            case .one: $0 = nil
            }
        }
    }
    case zero = 0
    case one = 1
}

enum BasicEnum : EnumeratesCasesAndLabels, CustomStringConvertible {
    // Swift's type inference gets a bit tripped up here... This is another way to solve it, but if you're not switching on your enum somewhere, you lose the protection of Swift's exhaustive switches
    static let enhancer = EnumEnhancer<BasicEnum>(cases: [.zero, .one])
    case zero
    case one
    var description: String {
        switch self {
        case .zero: return "zero"
        case .one: return "one"
        }
    }
    // BasicEnum is CustomStringConvertible, therefore we must provide a custom label
    var label: String {
        switch self {
        case .one: return "one"
        case .zero: return "zero"
        }
    }
}

enum AssociatedValueEnum<T: Initable> : EnumeratesCasesAndLabels, CustomStringConvertible {
    // This one has to be a computed property, since generic types can't have static storage yet
    static var enhancer: EnumEnhancer<AssociatedValueEnum<T>> {
        return EnhancedGenerator {
            switch $0 {
            case .none: $0 = .one(T())
            case .some(let theCase):
                switch theCase {
                case .one: $0 = .two(T(), T())
                case .two: $0 = nil
                }
            }
        }
    }
    
    case one(T)
    case two(T,T)
    var description: String {
        switch self {
        case .one (let msg): return "\(msg)"
        case .two (let msg): return "\(msg)"
        }
    }
    // Note that there is no custom `label` property even though there should be. The tests reflect that will return an error string.
}

class EnumEnhancerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCases() {
        let rawValueCases = "\([RawValueEnum.zero, RawValueEnum.one])"
        let rawValueLabels = "\([RawValueEnum.zero.label, RawValueEnum.one.label])"
        let rawValueLabel = "zero"
        XCTAssert(rawValueCases == "\(RawValueEnum.cases)", "Failed RawValueEnum.cases")
        XCTAssert(rawValueLabels == "\(RawValueEnum.labels)", "Failed RawValueEnum.labels")
        XCTAssert(rawValueLabel == "\(RawValueEnum.cases[0].label)", "Failed RawValueEnum.label")

        let basicCases = "\([BasicEnum.zero, BasicEnum.one])"
        let basicLabels = "\([BasicEnum.zero.label, BasicEnum.one.label])"
        let basicLabel = "zero"
        XCTAssert(basicCases == "\(BasicEnum.cases)", "Failed BasicEnum.cases")
        XCTAssert(basicLabels == "\(BasicEnum.labels)", "Failed BasicEnum.labels")
        XCTAssert(basicLabel == "\(BasicEnum.cases[0].label)", "Failed BasicEnum.label")

        let associatedCases = "\([AssociatedValueEnum<Foo>.one(Foo()), AssociatedValueEnum<Foo>.two(Foo(), Foo())])"
        let one = "one"
        let two = "two"
        let associatedLabels = "\([one, two])"
        let associatedLabel = AssociatedValueEnum<Foo>.enhancer.__CustomStringConvertibleErrorMessage__
        XCTAssert(associatedCases == "\(AssociatedValueEnum<Foo>.cases)", "Failed AssociatedValueEnum<Foo>.cases")
        XCTAssert(associatedLabels == "\(AssociatedValueEnum<Foo>.labels)", "Failed AssociatedValueEnum<Foo>.labels")
        XCTAssert(associatedLabel == "\(AssociatedValueEnum<Foo>.cases[0].label)", "Failed AssociatedValueEnum<Foo>.cases[0].label")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
