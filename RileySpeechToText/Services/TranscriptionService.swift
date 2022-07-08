//
//  TranscriptionService.swift
//  RileySpeechToText
//
//  Created by David Lichy on 7/7/22.
//

import AVFoundation
import Foundation
import Speech
import RxSwift
import RxCocoa
import Contacts

typealias TranscriptionResult = (String?, isFinal: Bool, errorMessage: String?)

extension String {
    static let speechRecognitionQueue = "com.burgersonbrioche.RileySpeechToText.speechRecognitionQueue"
}

extension DispatchQueue {
    static let speechRecognition = DispatchQueue(label: .speechRecognitionQueue, qos: .userInitiated)
}

typealias ConfidenceMap = [(NSRange, Float)]

class TranscriptionService: ObservableObject {
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }

    private var contextualStrings: [String] = []
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    private var disposeBag = DisposeBag()

    let onTransciption = PublishRelay<TranscriptionResult>()
    let transcriptions = BehaviorRelay<[(String, ConfidenceMap)]>(value: [])

    init() {
        recognizer = SFSpeechRecognizer()
        
        Task(priority: .userInitiated) {
            do {
                guard recognizer != nil else {
                    throw RecognizerError.nilRecognizer
                }
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                speechError(error)
            }
        }
       requestContactsPermissions()
    }
    
    deinit {
        reset()
    }

    func requestContactsPermissions(){
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] _, error in
            if error == nil {
                DispatchQueue.speechRecognition.async { [weak self] in
                    self?.loadContacts()
                }
            }
        }
    }
    
    func loadContacts(){
        let store = CNContactStore()
        let keys = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]
        do {
            let req = CNContactFetchRequest(keysToFetch: keys)
            try store.enumerateContacts(with: req) { [weak self] contact, _ in
                if !contact.familyName.isEmpty, !contact.givenName.isEmpty {
                    self?.contextualStrings += [
                        "\(contact.givenName) \(contact.familyName)"
                    ]
                    return
                }
                if !contact.givenName.isEmpty {
                    self?.contextualStrings += [
                        contact.givenName
                    ]
                    return
                }
                
                if !contact.familyName.isEmpty {
                    self?.contextualStrings += [
                        contact.familyName
                    ]
                    
                }
            }
        } catch let err {
            print(err.localizedDescription)
        }

    }
    
    
    func transcribe() {
        DispatchQueue.speechRecognition.async { [weak self] in
            guard let self = self, let recognizer = self.recognizer, recognizer.isAvailable else {
                self?.speechError(RecognizerError.recognizerIsUnavailable)
                return
            }
            
            do {
                let (audioEngine, request) = try Self.prepareEngine()
                self.audioEngine = audioEngine
                request.contextualStrings = self.contextualStrings
                self.request = request
                self.task = recognizer.recognitionTask(with: request, resultHandler: self.recognitionHandler(result:error:))
            } catch {
                self.reset()
                self.speechError(error)
            }
        }
    }
    
    func stopTranscribing() {
        reset()
    }
    
    func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        request.taskHint = .dictation
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    private func recognitionHandler(result: SFSpeechRecognitionResult?, error: Error?) {
        let isFinal = result?.isFinal ?? false
        let receivedError = error != nil
        if isFinal || receivedError {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        if let result = result {
            let transcriptions = result.transcriptions.map{ t -> (String, ConfidenceMap) in
                let confidenceMap = t.segments.map({ s in
                    return (s.substringRange, s.confidence)
                })
                return (t.formattedString, confidenceMap)
            }
            self.transcriptions.accept(transcriptions)
            onTransciption.accept((result.bestTranscription.formattedString,
                                   isFinal: isFinal, errorMessage: nil))
        }
    }

    private func speechError(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        onTransciption.accept((nil, isFinal: false, errorMessage: errorMessage))
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
