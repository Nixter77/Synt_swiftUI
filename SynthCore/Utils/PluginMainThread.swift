//
//  PluginMainThread.swift
//  SynthCore
//
//  AppKit view-controller state (preferredContentSize, views) is main-thread
//  only. The host calls AUAudioUnitFactory.createAudioUnit on the extension's
//  XPC queue; NSViewController.setPreferredContentSize: asserts off main, and
//  that NSException cannot unwind through Swift frames, so the extension dies
//  with SIGSEGV in objc_exception_rethrow ("Failed to load Audio Unit").
//

import Foundation

public enum PluginMainThread {
    /// Runs `work` now when already on main, otherwise asynchronously on main.
    public static func perform(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
