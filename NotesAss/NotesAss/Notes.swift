//
//  Notes.swift
//  NotesAss
//
//  Created by Stra1 T on 28.01.25.
//

import Foundation

import UIKit
import CoreData



struct Note {
    var id: UUID
    var headline: String
    var text: String
    var color: UIColor
}

class NotesViewController: UIViewController {
    var collectionView: UICollectionView!
    var notes: [Note] = []
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupCollectionView()
        fetchNotes()
        
    }
    
    func setupUI(){
        title = "Notes"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createNewNote))
    }
    
  
    
    @objc func createNewNote() {
        let newNote = Note(id: UUID(), headline: "", text: "", color: UIColor (red: CGFloat.random(in: 0.5...1.0), green: CGFloat.random(in: 0.5...1.0), blue: CGFloat.random(in: 0.5...1.0), alpha: 1.0))
        let editorVC = NoteEditorViewController(note: newNote)
        editorVC.onSave = { [weak self] note in
            guard let self = self else { return }
            self.notes.append(note)
            self.saveNoteToCoreData(note: note)
            self.collectionView.reloadData()
        }
        let navController = UINavigationController(rootViewController: editorVC)
        present(navController, animated: true)
    }

   
    
    func setupCollectionView() {
        let layout = PinterestLayout()
        layout.delegate = self
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(NoteCell.self, forCellWithReuseIdentifier: NoteCell.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        collectionView.addGestureRecognizer(longPressGesture)
    }
    
    @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point), gesture.state == .began {
            let note = notes[indexPath.item]
            let alert = UIAlertController(title: "Delete Note", message: "Are you sure you want to delete this note?", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                self.deleteNote(note)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }
    
    func fetchNotes() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        do {
            let entities = try context.fetch(request)
            notes = entities.map { entity in
                Note(id: entity.id!, headline: entity.headline!, text: entity.text!, color: UIColor(hex: entity.color!))
            }
            collectionView.reloadData()
        } catch {
            print("Error fetching notes: \(error)")
        }
    }
    
    func saveNoteToCoreData(note: Note) {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let entity = NoteEntity(context: context)
        entity.id = note.id
        entity.headline = note.headline
        entity.text = note.text
        entity.color = note.color.toHex()
        try? context.save()
    }
    
    func deleteNoteFromCoreData(note: Note) {
        
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        if let entities = try? context.fetch(request), let entity = entities.first {
            context.delete(entity)
            try? context.save()
        }
    }
    
    func deleteNote(_ note: Note) {
        deleteNoteFromCoreData(note: note)
        notes.removeAll { $0.id == note.id }
        collectionView.reloadData()
    }
}


extension NotesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NoteCell.identifier, for: indexPath) as! NoteCell
        cell.configure(with: notes[indexPath.item])
        return cell
    }
}

extension NotesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let note = notes[indexPath.item]
        let editorVC = NoteEditorViewController(note: note)
        editorVC.onSave = { updatedNote in
            self.notes[indexPath.item] = updatedNote
            self.saveNoteToCoreData(note: updatedNote)
            self.collectionView.reloadItems(at: [indexPath])
        }
        navigationController?.pushViewController(editorVC, animated: true)
    }
}

extension NotesViewController: PinterestLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, heightForItemAt indexPath: IndexPath, with width: CGFloat) -> CGFloat {
        let note = notes[indexPath.item]
        return note.text.height(withConstrainedWidth: width, font: UIFont.systemFont(ofSize: 16)) + 60 // Adjust as needed
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}

class NoteCell: UICollectionViewCell {
    static let identifier = "NoteCell"
    
    private let headlineLabel = UILabel()
    private let textLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        
        headlineLabel.font = .boldSystemFont(ofSize: 18)
        headlineLabel.numberOfLines = 1
        
        textLabel.font = .systemFont(ofSize: 16)
        textLabel.numberOfLines = 4
        textLabel.textColor = .darkGray
        
        let stackView = UIStackView(arrangedSubviews: [headlineLabel, textLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with note: Note) {
        contentView.backgroundColor = note.color
        headlineLabel.text = note.headline
        textLabel.text = note.text
    }
}


extension UIColor {
    func toHex() -> String {
        guard let components = cgColor.components else { return "#FFFFFF" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        scanner.scanHexInt64(&hexNumber)
        let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
        let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
        let b = CGFloat(hexNumber & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

class NoteEditorViewController: UIViewController {
    var note: Note
    var onSave: ((Note) -> Void)?
    
    private let headlineTextField = UITextField()
    private let textView = UITextView()
    
    init(note: Note) {
        self.note = note
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    func setupUI() {
        headlineTextField.font = .boldSystemFont(ofSize: 24)
        headlineTextField.text = note.headline
        headlineTextField.borderStyle = .roundedRect
        
        textView.font = .systemFont(ofSize: 18)
        textView.text = note.text
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.cornerRadius = 8
        
        let stackView = UIStackView(arrangedSubviews: [headlineTextField, textView])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveNote))
    }
    
    @objc func saveNote() {
        note.headline = headlineTextField.text ?? ""
        note.text = textView.text ?? ""
        onSave?(note)
        navigationController?.popViewController(animated: true)
    }
}


protocol PinterestLayoutDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView, heightForItemAt indexPath: IndexPath, with width: CGFloat) -> CGFloat
}

class PinterestLayout: UICollectionViewLayout {
    weak var delegate: PinterestLayoutDelegate?
    
    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0
    private let numberOfColumns = 2
    private let cellPadding: CGFloat = 8
    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        return collectionView.bounds.width
    }
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    override func prepare() {
        guard let collectionView = collectionView else { return }
        cache.removeAll()
        contentHeight = 0
        
        let columnWidth = contentWidth / CGFloat(numberOfColumns)
        var xOffset: [CGFloat] = []
        for column in 0..<numberOfColumns {
            xOffset.append(CGFloat(column) * columnWidth)
        }
        var column = 0
        var yOffset: [CGFloat] = Array(repeating: 0, count: numberOfColumns)
        
        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let indexPath = IndexPath(item: item, section: 0)
            let width = columnWidth - cellPadding * 2
            let height = delegate?.collectionView(collectionView, heightForItemAt: indexPath, with: width) ?? 180
            let frame = CGRect(x: xOffset[column], y: yOffset[column], width: columnWidth, height: height)
            let insetFrame = frame.insetBy(dx: cellPadding, dy: cellPadding)
            
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = insetFrame
            cache.append(attributes)
            contentHeight = max(contentHeight, frame.maxY)
            yOffset[column] += height
            
            column = column < (numberOfColumns - 1) ? (column + 1) : 0
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath.item]
    }
}
