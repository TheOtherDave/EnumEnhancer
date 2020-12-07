# EnumEnhancer
Someone on the swift-evolution list wanted a way to get an array containing the name (label) of every case in an enum, as well as an array of all possible cases. These classes and collection of three protocols (one for labels only, one for cases only, and one for both) does as much of the work for you as it can, and makes it a syntax error to not "fill in the blanks". Consult the comments in "EnumEnhancerTests.swift" for usage examples.

The master branch has been converted to Swift 3 syntax. In a move that will come as a complete surprise to everyone, the Swift-2.3 branch still uses the 2.3 syntax.

This is mostly obselete with the introduction of [SE-0194](https://github.com/apple/swift-evolution/blob/master/proposals/0194-derived-collection-of-enum-cases.md). However, the functionality is different in that it offers both an array of cases _and_ an array of case labels. GitHub is hosting this for free, so there's not really a reason to take it down. I _might_ update it to use SwiftSyntax or something similar at some point in the future, but I have no immediate plans to do so.
