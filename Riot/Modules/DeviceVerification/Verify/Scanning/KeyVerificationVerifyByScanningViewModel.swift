// File created from ScreenTemplate
// $ createScreen.sh Verify KeyVerificationVerifyByScanning
/*
 Copyright 2020 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

enum KeyVerificationVerifyByScanningViewModelError: Error {
    case unknown
}

final class KeyVerificationVerifyByScanningViewModel: KeyVerificationVerifyByScanningViewModelType {
    
    // MARK: - Properties
    
    // MARK: Private

    private let session: MXSession
    private let keyVerificationRequest: MXKeyVerificationRequest
    private let qrCodeDataCoder: MXQRCodeDataCoder
    private let keyVerificationManager: MXKeyVerificationManager
    
    private var qrCodeTransaction: MXQRCodeTransaction?
    private var scannedQRCodeData: MXQRCodeData?
    
    // MARK: Public

    weak var viewDelegate: KeyVerificationVerifyByScanningViewModelViewDelegate?
    weak var coordinatorDelegate: KeyVerificationVerifyByScanningViewModelCoordinatorDelegate?
    
    // MARK: - Setup
    
    init(session: MXSession, keyVerificationRequest: MXKeyVerificationRequest) {
        self.session = session
        self.keyVerificationManager = self.session.crypto.keyVerificationManager
        self.keyVerificationRequest = keyVerificationRequest
        self.qrCodeDataCoder = MXQRCodeDataCoder()
    }
    
    deinit {
        self.removePendingQRCodeTransaction()
    }
    
    // MARK: - Public
    
    func process(viewAction: KeyVerificationVerifyByScanningViewAction) {
        switch viewAction {
        case .loadData:
            self.loadData()
        case .scannedCode(payloadData: let payloadData):
            self.scannedQRCode(payloadData: payloadData)
        case .cannotScan:
            self.startSASVerification()
        case .acknowledgeOtherScannedMyCode(let acknowledgeOtherScannedMyCode):
            self.acknowledgeOtherScannedMyCode(acknowledgeOtherScannedMyCode)
        case .cancel:
            self.coordinatorDelegate?.keyVerificationVerifyByScanningViewModelDidCancel(self)
        case .acknowledgeMyUserScannedOtherCode:
            self.acknowledgeScanOtherCode()
        }
    }
    
    // MARK: - Private
    
    private func loadData() {
        
        let qrCodePlayloadData: Data?
        let canShowScanAction: Bool
        
        self.qrCodeTransaction = self.keyVerificationManager.qrCodeTransaction(withTransactionId: self.keyVerificationRequest.requestId)
        
        if let supportedVerificationMethods = self.keyVerificationRequest.myMethods {
            
            if let qrCodeData = self.qrCodeTransaction?.qrCodeData {
                qrCodePlayloadData = self.qrCodeDataCoder.encode(qrCodeData)
            } else {
                qrCodePlayloadData = nil
            }
            
            canShowScanAction = self.canShowScanAction(from: supportedVerificationMethods)
        } else {
            qrCodePlayloadData = nil
            canShowScanAction = false
        }
        
        let viewData = KeyVerificationVerifyByScanningViewData(qrCodeData: qrCodePlayloadData,
                                                               showScanAction: canShowScanAction)
        
        self.update(viewState: .loaded(viewData: viewData))
        
        self.registerTransactionDidStateChangeNotification()
    }
    
    private func canShowScanAction(from verificationMethods: [String]) -> Bool {
        return verificationMethods.contains(MXKeyVerificationMethodQRCodeScan)
    }
    
    private func update(viewState: KeyVerificationVerifyByScanningViewState) {
        self.viewDelegate?.keyVerificationVerifyByScanningViewModel(self, didUpdateViewState: viewState)
    }
    
    // MARK: QR code
    
    private func scannedQRCode(payloadData: Data) {
        self.scannedQRCodeData = self.qrCodeDataCoder.decode(payloadData)
        
        let isQRCodeValid = self.scannedQRCodeData != nil
        
        self.update(viewState: .scannedCodeValidated(isValid: isQRCodeValid))
    }
    
    private func acknowledgeScanOtherCode() {
        guard let scannedQRCodeData = self.scannedQRCodeData else {
            return
        }
        
        guard let qrCodeTransaction = self.qrCodeTransaction else {
            return
        }
        
        qrCodeTransaction.userHasScannedOtherQrCodeData(scannedQRCodeData)
        self.update(viewState: .loading)
    }
    
    private func acknowledgeOtherScannedMyCode(_ acknowledgeOtherScannedMyCode: Bool) {
        guard let qrCodeTransaction = self.qrCodeTransaction else {
            return
        }
        self.update(viewState: .loading)
        qrCodeTransaction.otherUserScannedMyQrCode(acknowledgeOtherScannedMyCode)
    }
    
    private func removePendingQRCodeTransaction() {
        guard let qrCodeTransaction = self.qrCodeTransaction else {
            return
        }
        self.keyVerificationManager.removeQRCodeTransaction(withTransactionId: qrCodeTransaction.transactionId)
    }
    
    // MARK: SAS
    
    private func startSASVerification() {
        
        self.update(viewState: .loading)
        
        self.session.crypto.keyVerificationManager.beginKeyVerification(from: self.keyVerificationRequest, method: MXKeyVerificationMethodSAS, success: { [weak self] (deviceVerificationTransaction) in
                guard let self = self else {
                    return
                }
            
                // Remove pending QR code transaction, as we are going to use SAS verification
                self.removePendingQRCodeTransaction()
            
                if deviceVerificationTransaction is MXOutgoingSASTransaction == false {
                    NSLog("[KeyVerificationVerifyByScanningViewModel] SAS transaction should be outgoing")
                    self.unregisterTransactionDidStateChangeNotification()
                    self.update(viewState: .error(KeyVerificationVerifyByScanningViewModelError.unknown))
                }
            
            }, failure: { [weak self] (error) in
                guard let self = self else {
                    return
                }
                self.update(viewState: .error(error))
            }
        )
    }
    
    // MARK: - MXKeyVerificationTransactionDidChange
    
    private func registerTransactionDidStateChangeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(transactionDidStateChange(notification:)), name: .MXKeyVerificationTransactionDidChange, object: nil)
    }
    
    private func unregisterTransactionDidStateChangeNotification() {
        NotificationCenter.default.removeObserver(self, name: .MXKeyVerificationTransactionDidChange, object: nil)
    }
    
    @objc private func transactionDidStateChange(notification: Notification) {
        guard let transaction = notification.object as? MXKeyVerificationTransaction else {
            return
        }
        
        guard let transactionDMEventId = transaction.dmEventId,
            self.keyVerificationRequest.requestId == transactionDMEventId else {
                return
        }
        
        if let sasTransaction = transaction as? MXSASTransaction {
            self.sasTransactionDidStateChange(sasTransaction)
        } else if let qrCodeTransaction = transaction as? MXQRCodeTransaction {
            self.qrCodeTransactionDidStateChange(qrCodeTransaction)
        }
    }
    
    private func sasTransactionDidStateChange(_ transaction: MXSASTransaction) {
        switch transaction.state {
        case MXSASTransactionStateShowSAS:
            self.unregisterTransactionDidStateChangeNotification()
            self.coordinatorDelegate?.keyVerificationVerifyByScanningViewModel(self, didStartSASVerificationWithTransaction: transaction)
        case MXSASTransactionStateCancelled:
            guard let reason = transaction.reasonCancelCode else {
                return
            }
            self.unregisterTransactionDidStateChangeNotification()
            self.update(viewState: .cancelled(reason))
        case MXSASTransactionStateCancelledByMe:
            guard let reason = transaction.reasonCancelCode else {
                return
            }
            self.unregisterTransactionDidStateChangeNotification()
            self.update(viewState: .cancelledByMe(reason))
        default:
            break
        }
    }
    
    private func qrCodeTransactionDidStateChange(_ transaction: MXQRCodeTransaction) {
        switch transaction.state {
        case .verified:
            self.unregisterTransactionDidStateChangeNotification()
            self.coordinatorDelegate?.keyVerificationVerifyByScanningViewModelDidCompleteQRCodeVerification(self)
        case .qrScannedByOther:
            self.update(viewState: .otherUserScannedMyCode)
        case .cancelled:
            guard let reason = transaction.reasonCancelCode else {
                return
            }
            self.unregisterTransactionDidStateChangeNotification()
            self.update(viewState: .cancelled(reason))
        case .cancelledByMe:
            guard let reason = transaction.reasonCancelCode else {
                return
            }
            self.unregisterTransactionDidStateChangeNotification()
            self.update(viewState: .cancelledByMe(reason))
        default:
            break
        }
    }
}
