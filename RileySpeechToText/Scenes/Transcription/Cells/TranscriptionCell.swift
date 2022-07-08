//
//  TranscriptionCell.swift
//  RileySpeechToText
//
//  Created by David Lichy on 7/7/22.
//

import Foundation
import UIKit

class TranscriptionCell: UITableViewCell {
    private let textView: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 0
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit(){
        setupViews()
        setupConstraints()
        setupAppearance()
    }

    private func setupViews(){
        addSubview(textView)
    }

    private func setupConstraints(){
        let padding = CGFloat(12)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            textView.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            bottomAnchor.constraint(equalTo: textView.bottomAnchor, constant: padding),
            trailingAnchor.constraint(equalTo: textView.trailingAnchor)
        ])
    }

    private func setupAppearance(){
        backgroundColor = .none
        
    }
    
    func set(item: TranscriptionItem){
        textView.attributedText = NSAttributedString(item.attributedString)
    }
}

