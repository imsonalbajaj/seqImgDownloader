//
//  ViewController.swift
//  seqImgDownloader
//
//  Created by Sonal on 25/08/26.
//

import UIKit

class ViewController: UIViewController {
    weak var tableView: UITableView!
    var images: [UIImage] = []
    var tasks: [Int: Task<Void, Never>] = [:]
    
    var imagesProcesses: [Int: UIImage] = [:] {
        didSet {
            DispatchQueue.main.async {
                while let image = self.imagesProcesses[self.images.count] {
                    let idx = self.images.count
                    self.imagesProcesses[idx] = nil
                    self.images.append(image)
                    self.tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .automatic)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let currTableView: UITableView = UITableView(frame: self.view.frame)
        self.view.addSubview(currTableView)
        
        currTableView.register(UINib(nibName: "CustomTableCell", bundle: nil), forCellReuseIdentifier: "CustomTableCell")
        currTableView.delegate = self
        currTableView.dataSource = self
        
        
        self.tableView = currTableView
    }
}

extension ViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        15
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: CustomTableCell = tableView.dequeueReusableCell(withIdentifier: "CustomTableCell") as! CustomTableCell
        
        let idx = indexPath.row
        
        if idx < images.count {
            let image = images[idx]
            cell.setImage(image: image)
        } else {
            cell.startLoader()
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        hitApiToGetImage(forItem: indexPath.row)
    }
    
    
    func hitApiToGetImage(forItem: Int) {
        print("func for \(forItem)")
        
        if images.count > forItem || imagesProcesses[forItem] != nil || tasks[forItem] != nil {
            return
        }
        
        print("api for \(forItem)")
        
        tasks[forItem] = Task.detached {
            
            let urlStr = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSoBVSCsSnkl9jGChkDwGbFSni3XsEV5Vk81tB12DEVGg&s"
            
            if let image = await self.fetchImage(from: urlStr) {
                
                print("downloaded for \(forItem)")
                
                
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.imagesProcesses[forItem] = image
                }
            }
            
            await MainActor.run {
                self.tasks[forItem] = nil
            }
        }
        
    }
    
    func fetchImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            print("Downloaded image of size: \(data.count)")
            return UIImage(data: data)
        } catch {
            print("Error downloading image: \(error)")
            return nil
        }
    }
}
