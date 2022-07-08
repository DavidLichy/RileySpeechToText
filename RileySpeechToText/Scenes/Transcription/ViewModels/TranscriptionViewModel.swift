//
//  TranscriptionViewModel.swift
//  RileySpeechToText
//
//  Created by David Lichy on 7/7/22.
//

import Foundation
import RxSwift
import RxCocoa
import Differentiator

import UIKit

enum AudioStatus {
case recording, recognizing, none
    
    var color: UIColor {
        switch self {
        case .recording:
            return .red
        case .recognizing:
            return .blue
        case .none:
            return .green
        }
    }
}

enum TranscriptionItem: Equatable {
    static func == (lhs: TranscriptionItem, rhs: TranscriptionItem) -> Bool {
        switch (lhs, rhs) {
        case let (.transcription(lhsItem), .transcription(rhsItem)):
            return lhsItem.0 == rhsItem.0
        }
    }
    case transcription((String, ConfidenceMap))
    var attributedString: AttributedString {
        switch self {
        case let .transcription((string, confMap)):
            let attributedString = NSMutableAttributedString(string: string)
            for (rng, cnf) in confMap {
                print(cnf)
                let color = UIColor(hue: CGFloat(cnf/3), saturation: 1, brightness: 1, alpha: 1)
                attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: rng)
            }
            return AttributedString(attributedString)
        }
    }
}

struct TranscriptionSection: SectionModelType {
    var items: [TranscriptionItem]
    
    init(original: TranscriptionSection, items: [TranscriptionItem]) {
        self.items = items
    }
    init(items: [TranscriptionItem]){
        self.items = items
    }
}

class TranscriptionViewModel {
    private var disposeBag = DisposeBag()
    let sections: BehaviorRelay<[TranscriptionSection]>
    let transcriptionService = TranscriptionService()
    let recognizedText: BehaviorRelay<String?>
    let audioStatus: BehaviorRelay<AudioStatus>
    init(){
        sections = .init(value: [.init(items: [])])
        recognizedText = .init(value: nil)
        audioStatus = .init(value: .none)
        
        transcriptionService.onTransciption
            .compactMap { $0.0 }
            .bind(to: recognizedText)
            .disposed(by: disposeBag)

        transcriptionService.onTransciption
            .filter { $0.0 != nil && $0.isFinal }
            .map{ _ in .none }
            .bind(to: audioStatus)
            .disposed(by: disposeBag)

        transcriptionService.transcriptions
            .map{[
                TranscriptionSection(items:
                    $0.map { trans -> TranscriptionItem in
                        return .transcription(trans)
                    }
                )
            ]}
            .bind(to: sections)
            .disposed(by: disposeBag)
    }
    
    func recordPressed(){
        switch audioStatus.value {
        case .recording:
            transcriptionService.stopTranscribing()
            audioStatus.accept(.none)
        case .recognizing:
            transcriptionService.stopTranscribing()
            audioStatus.accept(.none)
        case .none:
            transcriptionService.transcribe()
            audioStatus.accept(.recording)
        }
    }
}
