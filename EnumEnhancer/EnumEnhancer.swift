//
//  EnumEnhancer.swift
//  EnumEnhancer
//
//  Created by David Sweeris on 2016/01/16.
//  Copyright © 2016 David Sweeris. All rights reserved.
//

import Foundation

/// Conform to this protocol if don't want anything automatically generated.
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
/// Conform to this protocol if only want `Self.cases` to be automatically generated.
public protocol EnumeratesCases : EnhancedEnumWithEnhancer {}
extension EnumeratesCases {
    /// An automatically generated array of all possible cases.
    public static var cases: [Self] { return Self.enhancer.cases }
}

/// Conform to this protocol if only want `Self.labels` and `self.labels` to be automatically generated.
/// IMPORTANT!!! Note that conforming to CustomStringConvertible disables the mechanism used to automatically compute generate `self.label`. If your type conforms to CustomStringConvertible and you fail to provide your own implementation of `self.label`, this will return the wrong value. As soon as we can constrain types based on what they *don't* conform to, this will be moved there so that the compiler will let you know.
public protocol EnumeratesLabels : EnhancedEnumWithEnhancer {}
extension EnumeratesLabels {
    /// An automatically generated array of all possible case labels.
    public static var labels: [String] { return Self.enhancer.labels }
    // FIXME: Waiting on Swift to support "extension EnumeratesCasesAndLabels where !(Self: CustomStringConvertible) {}"
    /// IMPORTANT!!! Note that conforming to CustomStringConvertible disables the mechanism used to automatically compute this. If your type conforms to CustomStringConvertible and you fail to provide your own implementation, this will return the wrong value. As soon as we can constrain types based on what they *don't* conform to, this will be moved there so that the compiler will let you know.
    public var label: String {
        guard !(self is CustomStringConvertible) else {
            return Self.enhancer.__CustomStringConvertibleErrorMessage__
        }
        return "\(self)".componentsSeparatedByString("(").first ?? "<Error! Unknown error getting label>"
    }
}


/// Get two protocols for the price of one! Conform to this and watch the magic spring forth from your compiler!
/// Or the bugs. There might be bugs.
public protocol EnumeratesCasesAndLabels : EnumeratesCases, EnumeratesLabels {}




//protocol ParsingInit {
//    typealias EnhancedType: EnhancedEnum
//    init(path: String, line: Int, column: Int, caseMaker: ()->AnyGenerator<EnhancedType>)
//}
public class EnumEnhancer <T: EnhancedEnum> {
    public var __CustomStringConvertibleErrorMessage__: String { return "<Error! Cannot automatically extract labels when self is CustomStringConvertible>" }
    public typealias EnhancedType = T
    public let cases:    [T]
    public private (set) lazy var labels: [String] = { return self.cases.map { $0.label } }()
    internal init(_cases: [T]) {
        self.cases = _cases
    }
    internal init(_both: [(T, String)]) {
        self.cases  = _both.map { $0.0 }
        self.labels = _both.map { $0.1 }
    }
    public convenience init <S: SequenceType where S.Generator.Element == T> (cases: S) {
        self.init(_cases: Array(cases))
    }
    public convenience init <S: SequenceType where S.Generator.Element == (T, String)> (both: S) {
        self.init(_both: Array(both))
    }
    public convenience init <S1: SequenceType, S2: SequenceType where S1.Generator.Element == T, S2.Generator.Element == String> (cases: S1, labels: S2) {
        self.init(both: Array(zip(cases, labels)))
    }
}
extension EnumEnhancer {
    // If T: CustomStringConvertible, we have to parse the source code
    public convenience init(path:String = __FILE__, line:Int = __LINE__, column: Int = __COLUMN__, caseMaker: ()->AnyGenerator<T>) {
        self.init(both: zip(Array(caseMaker()), labelMaker(path: path, line: line, column: column, skipClosures: true)))
    }
}

public class EnhancedGenerator<T: EnhancedEnum> : EnumEnhancer<T> {
    public typealias Element = T
    /// Usage: Do NOT pass in anything other than next: (inout T?)->Void. The rest of the parameters all have default values that shouldn't be messed with... Unless you're being clever, of course. Then have at it, and please tell me about your cool idea!
    public init(path:String = __FILE__, line:Int = __LINE__, column: Int = __COLUMN__, next: (inout T?)->Void) {
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
internal func labelMaker(path path: String, line originalLine: Int, column: Int, skipClosures: Bool) -> [String] {
    var line = originalLine
    let lineTextArr = (try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding) as String)?.componentsSeparatedByString("\n") ?? []
    var caseDeclStartLine:Int = 0
    var caseDeclEndLine:Int = 0
    var foundStartOfCaseDecl = false
    
    func checkLine(line:String) -> Bool {
        let ans = !(line == "" || line.rangeOfString("//")?.startIndex == line.startIndex)
        return ans
    }
    if skipClosures {
        var closureCount = 0
        closureLoop: for lineNum in ((line - 1 < 0) ? line : line - 1) ..< lineTextArr.count {
            let lineText = lineTextArr[lineNum].stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
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
        let lineText = lineTextArr[lineNum].stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        
        switch foundStartOfCaseDecl {
        case false:
            if lineText.rangeOfString("case")?.startIndex == lineText.startIndex {
                caseDeclStartLine = lineNum
                foundStartOfCaseDecl = true
            }
        case true:
            if !(lineText.rangeOfString("case")?.startIndex == lineText.startIndex) {
                if checkLine(lineText) {
                    caseDeclEndLine = lineNum - 1
                    break parseLoop
                }
            }
        }
    }
    let foo = Array(lineTextArr[caseDeclStartLine...caseDeclEndLine])
        .map {$0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())}
        .filter {checkLine($0)}
        .map {$0.componentsSeparatedByCharactersInSet(NSCharacterSet.alphanumericCharacterSet().invertedSet)[1]}
    
    return foo
}
