//
//  EnumEnhancer.swift
//  EnumEnhancer
//
//  Created by David Sweeris on 2016/01/16.
//  Copyright © 2016 David Sweeris. All rights reserved.
//

import Foundation

/// Conform to this protocol if you don't want anything automatically generated.
public protocol EnhancedEnum {
    // These are all declared here instead of just in the protocol extension so that the compiler will grab any custom implementations.
    var label: String {get}
    static var cases:    [Self]             {get}
    static var labels:   [String]           {get}
}
extension EnhancedEnum {
    static public var count: Int { return Self.cases.count }
}

/// Just an interim protocol to require the enhancer... I don't think there's a reason to conform to this directly
public protocol EnhancedEnumWithEnhancer : EnhancedEnum {
    /// Unless your enum is CustomStringConvertible, this is the only variable that you actually have to create yourself. With the exception of "self.label", everything else can be automatically generated through protocol extensions by conforming your type to 'EnumeratesCasesAndLabels'
    static var enhancer: EnumEnhancer<Self> {get}
}
/// Conform to this protocol if you only want `Self.cases` to be automatically generated.
public protocol EnumeratesCases : EnhancedEnumWithEnhancer {}
extension EnumeratesCases {
    /// An automatically generated array of all possible cases.
    public static var cases: [Self] { return Self.enhancer.cases }
}

/// Conform to this protocol if you only want `Self.labels` and `self.labels` to be automatically generated.
/// IMPORTANT!!! Note that conforming to CustomStringConvertible disables the mechanism used to automatically compute generate `self.label`. If your type conforms to CustomStringConvertible and you fail to provide your own implementation of `self.label`, this will return the wrong value. As soon as we can constrain types based on what they *don't* conform to, this will be moved there so that the compiler will let you know.
public protocol EnumeratesLabels : EnhancedEnumWithEnhancer {}
extension EnumeratesLabels {
    /// An automatically generated array of all possible case labels.
    public static var labels: [String] { return Self.enhancer.labels }
    // TODO: Waiting on Swift to support "extension EnumeratesCasesAndLabels where !(Self: CustomStringConvertible) {}"
    /// IMPORTANT!!! Note that conforming to CustomStringConvertible disables the mechanism used to automatically compute this. If your type conforms to CustomStringConvertible and you fail to provide your own implementation, this will return the wrong value. As soon as we can constrain types based on what they *don't* conform to, this will be moved there so that the compiler will let you know.
    public var label: String {
        guard !(self is CustomStringConvertible) else {
            return Self.enhancer.__CustomStringConvertibleErrorMessage__
        }
        return "\(self)".components(separatedBy: "(").first ?? "<Error! Unknown error getting label>"
    }
}


/// Get two protocols for the price of one! Conform to this and watch the magic spring forth from your compiler!
/// Or the bugs. There might be bugs.
public protocol EnumeratesCasesAndLabels : EnumeratesCases, EnumeratesLabels {}




//protocol ParsingInit {
//    typealias EnhancedType: EnhancedEnum
//    init(path: String, line: Int, column: Int, caseMaker: ()->AnyGenerator<EnhancedType>)
//}
open class EnumEnhancer <T: EnhancedEnum> {
    open var __CustomStringConvertibleErrorMessage__: String { return "<Error! Cannot automatically extract labels when self is CustomStringConvertible>" }
    public typealias EnhancedType = T
    open let cases:    [T]
    open fileprivate (set) lazy var labels: [String] = { return self.cases.map { $0.label } }()
    internal init(_cases: [T]) {
        self.cases = _cases
    }
    internal init(_both: [(T, String)]) {
        self.cases  = _both.map { $0.0 }
        self.labels = _both.map { $0.1 }
    }
    public convenience init <S: Sequence> (cases: S) where S.Iterator.Element == T {
        self.init(_cases: Array(cases))
    }
    public convenience init <S: Sequence> (both: S) where S.Iterator.Element == (T, String) {
        self.init(_both: Array(both))
    }
    public convenience init <S1: Sequence, S2: Sequence> (cases: S1, labels: S2) where S1.Iterator.Element == T, S2.Iterator.Element == String {
        self.init(both: Array(zip(cases, labels)))
    }
}
extension EnumEnhancer {
    // If T: CustomStringConvertible, we have to parse the source code
    public convenience init(path:String = #file, line:Int = #line, column: Int = #column, caseMaker: ()->AnyIterator<T>) {
        self.init(both: zip(Array(caseMaker()), labelMaker(path: path, line: line, column: column, skipClosures: true)))
    }
}

open class EnhancedGenerator<T: EnhancedEnum> : EnumEnhancer<T> {
    public typealias Element = T
    /// Usage: Do NOT pass in anything other than next: (inout T?)->Void. The rest of the parameters all have default values that shouldn't be messed with... Unless you're being clever, of course. Then have at it, and please tell me about your cool idea!
    public init(path:String = #file, line:Int = #line, column: Int = #column, next: (inout T?)->Void) {
        var element: T? = nil
        let lLabels = labelMaker(path: path, line: line, column: column, skipClosures: true)
        var lCases = [T]()
        next(&element)
        while element != nil {
            lCases.append(element!)
            next(&element)
        }
        super.init(_both: Array(zip(lCases, lLabels)))
    }
}

/// This is where all the actual parsing gets done. I have *very* little experience writing parsers, so... yeah... I *think* it works.
internal func labelMaker(path: String, line originalLine: Int, column: Int, skipClosures: Bool) -> [String] {
    var line = originalLine
    let lineTextArr = (try? NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue) as String)?.components(separatedBy: "\n") ?? []
    var caseDeclStartLine:Int = 0
    var caseDeclEndLine:Int = 0
    var foundStartOfCaseDecl = false
    
    func checkLine(_ line:String) -> Bool {
        let ans = !(line == "" || line.range(of: "//")?.lowerBound == line.startIndex)
        return ans
    }
    if skipClosures {
        var closureCount = 0
        closureLoop: for lineNum in ((line - 1 < 0) ? line : line - 1) ..< lineTextArr.count {
            let lineText = lineTextArr[lineNum].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            for c in lineText.characters {
                switch c {
                case "{": closureCount += 1
                case "}": closureCount -= 1
                default: break
                }
            }
            if closureCount == 0 {
                line = lineNum
                break closureLoop
            }
        }
    }
    parseLoop: for lineNum in line ..< lineTextArr.count {
        let lineText = lineTextArr[lineNum].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        switch foundStartOfCaseDecl {
        case false:
            if lineText.range(of: "case")?.lowerBound == lineText.startIndex {
                caseDeclStartLine = lineNum
                foundStartOfCaseDecl = true
            }
        case true:
            if !(lineText.range(of: "case")?.lowerBound == lineText.startIndex) {
                if checkLine(lineText) {
                    caseDeclEndLine = lineNum - 1
                    break parseLoop
                }
            }
        }
    }
    let foo = Array(lineTextArr[caseDeclStartLine...caseDeclEndLine])
        .map {$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)}
        .filter {checkLine($0)}
        .map {$0.components(separatedBy: CharacterSet.alphanumerics.inverted)[1]}
    
    return foo
}
