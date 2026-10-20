//
//  SyntAUFactory.swift
//  SyntAUv3
//
//  Principal class of the Audio Unit extension. The view arrives in stage 4.
//

import AudioToolbox
import Foundation
import SynthCore

@objc(SyntAUFactory)
public final class SyntAUFactory: NSObject, AUAudioUnitFactory {
    public func beginRequest(with context: NSExtensionContext) {}

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        try SyntAudioUnit(componentDescription: componentDescription, options: [])
    }
}
