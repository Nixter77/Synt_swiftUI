//
//  SyntArpAUViewController.swift
//  SyntArpAUv3
//
//  Factory for the MIDI FX. No synthesizer UI.
//

import CoreAudioKit
import Foundation

@objc(SyntArpAUViewController)
public final class SyntArpAUViewController: AUViewController, AUAudioUnitFactory {
    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        preferredContentSize = NSSize(width: 400, height: 120)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        preferredContentSize = NSSize(width: 400, height: 120)
    }

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        try SyntArpAudioUnit(componentDescription: componentDescription, options: [])
    }
}
