//
//  Notes.swift
//  NotesAss
//
//  Created by Stra1 T on 28.01.25.
//


import Foundation
import CoreData
import UIKit


@objc(NoteEntity)
public class NoteEntity: NSManagedObject {
    
}

extension NoteEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NoteEntity> {
        return NSFetchRequest<NoteEntity>(entityName: "NoteEntity")
    }

    @NSManaged public var text: String?
    @NSManaged public var headline: String?
    @NSManaged public var collor: String?
    @NSManaged public var id: UUID?

}

extension NoteEntity : Identifiable {

}
struct Note {
    var id: UUID
    var headline: String
    var text: String
    var color: UIColor
}

class NotesViewController: UIViewController, UISearchBarDelegate {
    var collectionView: UICollectionView!
    var notes: [Note] = []
    let searchBar = UISearchBar()
    private var isSearching = false
    var filteredNotes: [Note] = []
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setUpSearchBar()
        setupUI()
        setupCollectionView()
        fetchNotes()
        
    }
    
    func setupUI(){
        title = "Notes"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createNewNote))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(showSearchBar))
    }
    
    @objc func showSearchBar(){
        navigationItem.titleView = searchBar
        searchBar.isHidden = false
        searchBar.becomeFirstResponder()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSearch))
        isSearching = true
    }
    
    @objc func cancelSearch(){
        searchBar.isHidden = true
        navigationItem.titleView = nil
        navigationItem.title = "Notes"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(showSearchBar))
        
        isSearching = false
        filteredNotes = notes
        collectionView.reloadData()
        
    }
    
    func setUpSearchBar(){
        searchBar.delegate = self
        searchBar.placeholder = "Search Note"
        searchBar.isHidden = true
        searchBar.returnKeyType = .done
        searchBar.sizeToFit()
    }
    
    
    @objc func createNewNote() {
        if isSearching {
            cancelSearch()
        }
        let newNote = Note(id: UUID(), headline: "", text: "", color: UIColor (red: CGFloat.random(in: 0.5...1.0), green: CGFloat.random(in: 0.5...1.0), blue: CGFloat.random(in: 0.5...1.0), alpha: 1.0))
        let editorVC = NoteEditorViewController(note: newNote)
        editorVC.onSave = { [weak self] note in
            guard let self = self else { return }
            self.notes.append(note)
            self.saveNoteToCoreData(note: note)
            
            self.collectionView.reloadData()
            self.dismiss(animated: true)
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
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        do {
            let entities = try context.fetch(request)
            notes = entities.map { entity in
                Note(id: entity.id ?? UUID(), headline: entity.headline ?? "", text: entity.text ?? "", color: UIColor(hex: entity.collor ?? "FFFFFF") ?? .white
                )
            }
            collectionView.reloadData()
        } catch {
            print("Error fetching notes: \(error)")
        }
    }
    
    func saveOrUpdateNoteInCoreData(note: Note) {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                // Update existing note
                entity.headline = note.headline
                entity.text = note.text
                entity.collor = note.color.toHex()
            } else {
                // Create a new note
                let newEntity = NoteEntity(context: context)
                newEntity.id = note.id
                newEntity.headline = note.headline
                newEntity.text = note.text
                newEntity.collor = note.color.toHex()
            }
            try context.save()
            
        } catch {
            print("Error saving or updating note: \(error)")
        }
    }
    func saveNoteToCoreData(note: Note) {
        
        let entity = NoteEntity(context: context)
        entity.id = note.id
        entity.headline = note.headline
        entity.text = note.text
        entity.collor = note.color.toHex()
        try? context.save()
    }
    
    func deleteNoteFromCoreData(note: Note) {
        let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
        let entities = try? context.fetch(request)
        
        if let entity = entities?.first {
            context.delete(entity)
            try? context.save()
        }else{
            print("note not found")
        }
    }
    
    func deleteNote(_ note: Note) {
        deleteNoteFromCoreData(note: note)
        notes.removeAll { $0.id == note.id }
        collectionView.reloadData()
    }
    
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredNotes = notes
        } else {
            filteredNotes = notes.filter { $0.headline.lowercased().contains(searchText.lowercased()) }
        }
        collectionView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}




extension NotesViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isSearching ? filteredNotes.count : notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let note = isSearching ? filteredNotes[indexPath.item] : notes[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCell", for: indexPath) as! NoteCell
        cell.configure(with: note)
        return cell
    }
}

extension NotesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let note = isSearching ? filteredNotes[indexPath.item] : notes[indexPath.item]
        let editorVC = NoteEditorViewController(note: note)
            
        editorVC.onSave = { [weak self] updatedNote in
            guard let self = self else {return}
            
            if let originalIndex = self.notes.firstIndex(where: {$0.id == updatedNote.id}){
                self.notes[originalIndex] = updatedNote
                self.saveOrUpdateNoteInCoreData(note: updatedNote)
            }
            
            if self.isSearching {
                self.filteredNotes = self.notes.filter {$0.headline.lowercased().contains(self.searchBar.text?.lowercased() ?? "")}
            }
            
            self.collectionView.reloadData()
            
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
        headlineLabel.numberOfLines = 0
        
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
        guard let components = cgColor.components, components.count >= 3 else {
            return "000000"
        }
        let r = components[0]
        let g = components[1]
        let b = components[2]
        return String(format: "#%02X%02X%02X", Int(r*255),Int(g*255),Int(b*255))
    }
    
    convenience init?(hex: String) {
        var hexSnt = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSnt = hexSnt.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSnt).scanHexInt64(&rgb)
       
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
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
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor
        textView.layer.backgroundColor = UIColor(red: 0.0, green: 202.0, blue: 255.0, alpha: 0.03).cgColor
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
