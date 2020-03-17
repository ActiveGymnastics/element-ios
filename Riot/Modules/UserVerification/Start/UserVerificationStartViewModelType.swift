// File created from ScreenTemplate
// $ createScreen.sh Start UserVerificationStart
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

protocol UserVerificationStartViewModelViewDelegate: class {
    func userVerificationStartViewModel(_ viewModel: UserVerificationStartViewModelType, didUpdateViewState viewSate: UserVerificationStartViewState)
}

protocol UserVerificationStartViewModelCoordinatorDelegate: class {
    
    func userVerificationStartViewModel(_ viewModel: UserVerificationStartViewModelType, otherDidAcceptRequest request: MXKeyVerificationRequest)
    
    func userVerificationStartViewModel(_ viewModel: UserVerificationStartViewModelType, didCompleteWithIncomingTransaction transaction: MXSASTransaction)
    
    func userVerificationStartViewModel(_ viewModel: UserVerificationStartViewModelType, didTransactionCancelled transaction: MXSASTransaction)
    
    func userVerificationStartViewModelDidCancel(_ viewModel: UserVerificationStartViewModelType)
}

/// Protocol describing the view model used by `UserVerificationStartViewController`
protocol UserVerificationStartViewModelType {
            
    var viewDelegate: UserVerificationStartViewModelViewDelegate? { get set }
    var coordinatorDelegate: UserVerificationStartViewModelCoordinatorDelegate? { get set }
    
    func process(viewAction: UserVerificationStartViewAction)
}
