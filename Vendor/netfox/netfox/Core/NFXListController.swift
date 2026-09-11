//
//  NFXListController.swift
//  netfox
//
//  Copyright © 2016 netfox. All rights reserved.
//

import Foundation


class NFXListController: NFXGenericController {

    // MARK: - Public Properties
    
    private(set) var tableData = [NFXHTTPModel]() {
        didSet {
            reloadData()
        }
    }
    
    var filter: String? = nil {
        didSet {
            filterModels()
        }
    }
    
    // MARK: - Private Properties
    
    // Sabit çekim (vendored, upstream'de düzeltilmedi): bu alan `lazy` idi ve `deinit`
    // `cancel()` çağırıyordu. Sekme hiç açılmadıysa `viewDidLoad` koşmaz, lazy ilkleme
    // `deinit` İÇİNDE tetiklenir; kapanış `[weak self]` ile deallocate olmakta olan nesneye
    // weak referans kurmaya çalışır ve ObjC runtime abort eder ("Cannot form weak reference
    // ... in the process of deallocation"). TestFlight 3.0 (43), netfox kapatılırken.
    // Abonelik artık `viewDidLoad`'da kurulur; kurulmadıysa `deinit`'te dokunulacak şey yok.
    private var dataSubscription: Subscription<[NFXHTTPModel]>?
    
    private var allModels = [NFXHTTPModel]() {
        didSet {
            filterModels()
        }
    }
    
    // MARK: - Overloads
    
    deinit {
        dataSubscription?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let subscription = Subscription<[NFXHTTPModel]> { [weak self] in self?.allModels = $0 }
        dataSubscription = subscription
        NFXHTTPModelManager.shared.publisher.subscribe(subscription)
        populate(with: NFXHTTPModelManager.shared.filteredModels)
    }
    
    // MARK: - Public Methods
    
    func populate(with models: [NFXHTTPModel]) {
        allModels = models
    }

    // MARK: - Private Methods
    
    private func filterModels() {
        guard let filter = filter, filter.isEmpty == false else {
            tableData = allModels
            return
        }
        
        tableData = allModels.filter {
            $0.requestURL?.range(of: filter, options: [.caseInsensitive, .diacriticInsensitive]) != nil ||
            $0.requestMethod?.range(of: filter, options: [.caseInsensitive, .diacriticInsensitive]) != nil ||
            $0.responseType?.range(of: filter, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
    
}
