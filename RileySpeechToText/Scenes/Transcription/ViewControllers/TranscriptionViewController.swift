//
//  TranscriptionViewController.swift
//  RileySpeechToText
//
//  Created by David Lichy on 7/7/22.
//

import RxSwift
import RxCocoa
import RxDataSources

class TranscriptionViewController: UIViewController {
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var viewModel: TranscriptionViewModel?
    private var disposeBag = DisposeBag()
    private let tableView: UITableView = {
        let view = UITableView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let textView: UITextView = {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let recordButton: RecordButton = {
        let view = RecordButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        commonInit()
    }
    
    func commonInit(){
        setupViews()
        setupConstraints()
        setupAppearance()
        configure(with: TranscriptionViewModel())
    }
    
    private func setupViews(){
        view.addSubview(textView)
        view.addSubview(recordButton)
        view.addSubview(tableView)
        tableView.register(TranscriptionCell.self, forCellReuseIdentifier: "TranscriptionCell")
    }

    private func setupConstraints(){
        let padding = CGFloat(24)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide .topAnchor, constant: padding * 4),
            textView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.2),
            view.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: padding),
            
            
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            tableView.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: padding),
            recordButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: padding),
            view.trailingAnchor.constraint(equalTo: tableView.trailingAnchor, constant: padding),
            
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.1),
            recordButton.widthAnchor.constraint(equalTo: recordButton.heightAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: padding * 4)
        ])
    }

    func configure(with viewModel: TranscriptionViewModel){
        self.viewModel = viewModel
        viewModel.recognizedText
            .compactMap{ $0 }
            .observe(on: MainScheduler.instance)
            .bind(to: textView.rx.text)
            .disposed(by: disposeBag)
        
        viewModel.audioStatus
            .observe(on: MainScheduler.instance)
            .bind(to: recordButton.rx.status)
            .disposed(by: disposeBag)

        
        viewModel.sections
            .observe(on: MainScheduler.instance)
            .bind(to: tableView.rx.items(dataSource: getDataSource()))
            .disposed(by: disposeBag)
        
        recordButton.rx.tap
            .subscribe { [weak self] _ in
                self?.viewModel?.recordPressed()
            }
            .disposed(by: disposeBag)
    }
    
    private func setupAppearance(){
        tableView.separatorStyle = .none
        tableView.separatorInset = .init(top: 12, left: 12, bottom: 12, right: 12)
        textView.backgroundColor = .white.withAlphaComponent(0.1)
        textView.layer.cornerRadius = 12
        textView.textColor = .white
        textView.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        textView.textContainerInset = .init(top: 12, left: 12, bottom: 12, right: 12)
        recordButton.backgroundColor = .green
    }


}

private extension Reactive where Base: RecordButton {
    var status: Binder<AudioStatus> {
        let binding: (RecordButton, AudioStatus) -> Void = { target, value in
            target.handle(status: value)
        }
        return Binder(base, binding: binding)
    }
}

extension TranscriptionViewController {
    func getDataSource() -> RxTableViewSectionedReloadDataSource<TranscriptionSection> {
        return .init { _, tableView, indexPath, item in
            switch item {
            case .transcription:
                let cell = tableView.dequeueReusableCell(withIdentifier: "TranscriptionCell", for: indexPath)
                if let cell = cell as? TranscriptionCell {
                    cell.set(item: item)
                }
                return cell
            }
        }
    }
}

private class RecordButton: UIButton {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        self.layer.maskedCorners = [.layerMaxXMaxYCorner,.layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner]
        self.layer.cornerRadius = rect.height / 2
        self.clipsToBounds = true
    }

    func handle(status: AudioStatus){
        backgroundColor = status.color
        generator.prepare()
        generator.impactOccurred()
    }
}
