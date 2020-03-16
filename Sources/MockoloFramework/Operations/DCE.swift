//
//  Copyright (c) 2018. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

//public typealias Loc = (name: String, docLoc: (Int, Int))
//public struct Entry {
//    var path: String
//    var module: String
//    var parents: [String]
//    var docLoc: (Int, Int)
//}


/*
 
 First, scan all the classes declared, and generate a map: key == class name, val == path, module, used_bit
 
 Second, scan all the classes used -- in var decls, type params, in func/var bodies and globally, and generate a
 used_list of classes
 
 Third, go through first map, check if key and val (key's parents) are in used_map, if not, mark it unused.
 
 Fourth, go through unused_map, remove class decl for each entry.
 
 */

final public class Val {
    let path: String
    let parents: [String]
    let offset: Int
    let length: Int
    var used = false
    public init(path: String,
                parents: [String],
                offset: Int64,
                length: Int64,
                used: Bool) {
        self.path = path
        self.parents = parents
        self.offset = Int(offset)
        self.length = Int(length)
        self.used = used
    }
}

public func dce(sourceDirs: [String],
                exclusionSuffixes: [String]? = nil,
                exclusionSuffixesForUsed: [String]? = nil,
                outputFilePath: String? = nil,
                concurrencyLimit: Int? = nil) {
    
    let p = ParserViaSourceKit()
    
    let limit = concurrencyLimit ?? 12
    let sema = DispatchSemaphore(value: limit)
    let dceq = DispatchQueue(label: "dce-q", qos: DispatchQoS.userInteractive, attributes: DispatchQueue.Attributes.concurrent)
    
    
    let t0 = CFAbsoluteTimeGetCurrent()
    #if ALL
    log("Scan all class decls...")
    var results = [String: Val]()
    p.scanDecls(dirs: sourceDirs, exclusionSuffixes: exclusionSuffixes, queue: dceq, semaphore: sema) { (subResults: [String : Val]) in
        for (k, v) in subResults {
            results[k] = v
        }
    }
    let t1 = CFAbsoluteTimeGetCurrent()
    log("--", t1-t0)
    
    log("Scan used class decls...")
    var usedMap = [String: Bool]()
    p.scanUsedDecls(dirs: sourceDirs, exclusionSuffixes: exclusionSuffixesForUsed, queue: dceq, semaphore: sema) { (subResults: [String]) in
        for r in subResults {
            usedMap[r] = false
        }
    }
    let t2 = CFAbsoluteTimeGetCurrent()
    log("--", t2-t1)
    
    log("Filter unused decls...")
    var unusedMap = [String: Val]()
    for (k, v)  in results {        
        if let usedVal = usedMap[k] {
            for p in v.parents {
                results[p]?.used = true
            }
        }
    }

    for (k, v)  in results {
        if let _ = usedMap[k] {
            // used
        } else if v.used {
            // used
        } else {
            unusedMap[k] = v
        }
    }


    let t3 = CFAbsoluteTimeGetCurrent()
    log("--", t3-t2)
    
    log("Save results...")
    if let outputFilePath = outputFilePath {
//        let declared = results.map {"\($0.key): \($0.value)"}.joined(separator: "\n")
        let used = usedMap.map {"\($0.key)"}.joined(separator: ", ")
        let ret = unusedMap.map {"\($0.key): \($0.value.path)"}.joined(separator: "\n")

//        try? declared.write(toFile: filepath+"-decl", atomically: true, encoding: .utf8)
        try? used.write(toFile: outputFilePath+"-used", atomically: true, encoding: .utf8)
        try? ret.write(toFile: outputFilePath+"-ret", atomically: true, encoding: .utf8)
        log(" to ", outputFilePath)
    }
    let t4 = CFAbsoluteTimeGetCurrent()
    log("--", t4-t3)
    let paths = unusedMap.values.flatMap{$0.path}
    let pathSet = Set(paths)
    let dpaths = results.values.flatMap{$0.path}
    let dpathSet = Set(dpaths)
    log("#Declared", results.count, "#Paths with unused classes", dpathSet.count)
    log("#Used", usedMap.count)
    log("#Unused", unusedMap.count, "#Paths with unused classes", pathSet.count)


    p.removeUnusedDecls(declMap: unusedMap, queue: dceq, semaphore: sema) { (d: Data, url: URL) in
        try? d.write(to: url)
    }
    let t5 = CFAbsoluteTimeGetCurrent()
    log("Removed unused decls", t5-t4)
    #endif


    let allList = list.components(separatedBy: "\n")
    var removeList = [String]()
    p.checkUnused(sourceDirs, unusedList: allList, exclusionSuffixes: exclusionSuffixesForUsed, queue: dceq, semaphore: sema) { (toRemove: [String]) in
        removeList.append(contentsOf: toRemove)
    }

    var umap = [String: Val]()
    for a in allList {
        if !removeList.contains(a) {
            umap[a] = Val(path: "", parents: [], offset: 0, length: 0, used: true)
        }
    }
    print(umap)

    p.updateTests(dirs: sourceDirs, unusedMap: umap, queue: dceq, semaphore: sema) { (d: Data, url: URL, deleteFile: Bool) in
        if deleteFile {
            try? FileManager.default.removeItem(at: url)
        } else {
            try? d.write(to: url)
        }
    }
    let t6 = CFAbsoluteTimeGetCurrent()
    log("Removed unused decls", t6-t0)

    log("Total (s)", t6-t0)
}



let list = """
EmptyDetailPaymentFlowProviderImpl
HubMessagingActionHandlerPluginPointImpl
ScheduledRidesMenuItemBuilder
DidFinishPickupStepToConfirmationEventHandler
SelectionFeedbackGenerator
ProfileIntroViewController_DEPRECATED
MapCameraCoordinator
SafeViewController
ReceivingWebViewAction
SynchronizedUnboundedDeque
SearchJobFilterUtil
EmailVerificationFlowStep
ThemeObserver
FinancialAccountDetailsBuilder
ContactPickerExampleSectionAddition
UPIDisplayable
FireflyAnalyticsCacheStream
UberMoneyUpdateAddressBuilder
PinCalloutView
ActivityFeedItemBaseView
AuditInteractionRecordStream
HCVRoutelinePickupLayerComponentBuilder
NavigationItemView
PassGeoCellBuilder
HelpTripSummarySectionProvider
KeyedSynchronousPluginPoint
Component_DEPRECATED
MapMarkerPolygon
ThemeableCollectionViewComponent
UnsafeViewController
DefaultConfirmationActionRequestStyle
AccountSettingsFlowBuilder
AppendMetricsSpanInterceptor
HHGzipRequestInterceptor
ShareLocationWorkerDependencyImpl
RideCheckButtonWorkerDependencyImpl_DEPRECATED
HelpPredictionUtils
EnhancedDispatchingPhaseConnecting
OTTCustomerContactStream
UGCCollectionComponent
PromoSummarySectionHeader
ContactPickerInteractor
OldRootBuilder
AsynchronousPaymentDisplayableProviderImplNew
HubMessagingUserInteractionReporterPluginContextImpl
ThumbRatingComponent
BaseProfileSectionViewModelBuilder
PassTrackingTitleCell
PremiumProductSupportConfig
HelpSeparatorSectionProvider
PaymentOnboardingPluginPointImpl
MutableFareEstimateRequestImpl
WebViewExperiments
HelpJobHelpEmptyPluginPoint
TooltipViewRegistry
FreeRidesShareCTAButton
HelpHomeMessagesCardDefaultPluginFactory
MobileStudioThemeDark
ReusableInteractor
StorageCapacityStreamFactory
EtaProvider
AnimatedComponent
EmptyHeaderAndTitleCell
DidFinishPickupStepToDropoffEditEventHandler
ImageViewLoadingDelegateStub
EmojisSurveyStepAlertViewController
MapViewExperimentAccessor
HCVRouteListCell
FirstTimeExperienceTooltipCell
MyView2
ExperimentGroupNamesRiderBugReporter
InfoOverlay
VoucherSelectorDependencyAdapter
ParameterKeyObjC
QRScannerButton
AuditableValueGenerator
JWTConstants
ChipSelectionComponent
MutableMobileStudioTriggerStateStream
CommandUX
ShowGrantPaymentStepPluginFactory
TripTrackerPluginContextClass
HubMessagingSharedImpl
PassTrackingUsageCell
SharedSecretAuthorityProvider
ExpenseProviderListPresenter
PassPurchasePaymentStepViewControllerListenerProvider
ExperimentParameterDefaultsEMobility
OffTripNavigationCancelSectionViewController
TripProgressView
PoolPrebookingRemindersWorkflowDependenciesHolderMock
CompareProductCellProvider
ViewAuditEventRecordPairStream
ScheduledUpsellTripsRequestStatusStream
BugReporterWindowRootViewController
DirectLineInfoRequestWorkerPluginFactory
PaymentOnboardingBuilder
SampleAppSystemPermissionAnalyticsReporter
LowBalanceActionSheetController
DirectLineMapLayerController
CompositeLogger
UberTracer
RealtimeHubMessagingRamenMessageStandinFactory
SwitchComponentBinder
RxNotifiyingBoundedDeque
UGCPhotoUploadComponent
adrListener
ButtonComponent
DropDownPickerView
AirlineInfo
VenuePositionableImpl
FeaturedRewardCollectionViewModel
TripIssuesListPluginPointImpl
RecommendedProductCellProvider
ConversationDetailsEmptyPluginPoint
IDVerificationView
HelpHomeIssueListCardDefaultPluginFactory
EMobilityCameraConfirmationBuilder
SettingsRowContextImpl
LoadingImageView
Greeter
ButtonCardCellProvider
UGCCollectionBuilder
GoOfflineWorker
FormTextViewComponent
FavoritesCacheManager
PricingLabelFactoryImpl
TraceReceiver
JumpOpsSharedMapLayerWorker
ProductSelectionV1DataImage
BatchingItineraryStopView
VenuePickerMaskView
DidTapPickupEditEntryPointToPickupStepEventHandler
UberCashAddFundsAutoRefillBuilder
DriverMenuNotificationAdapter
FreeRidesOpportunityView
DemandShapingScheduleUtilities
ScheduledRidesTimePickerBuilder
RerequestUtilities
TransitBaseAlertController
Bash
RentalContactProviderBuilder
PassTrackingUsagePricingCell
IllustrationHeaderViewBuilder
RewardsMarkdownTextView
ProtoEnabledChecker
LooseTypedMapper
BindableFareInfo
SelectedProductBottomSheetView
DispatchingSecondaryBuilder
ThemeableBaseFormView
PoolHeliumConfirmationActionRequestStyle
PickupWindowStreamTestMock
HelpIssueEmptyPluginPoint
BKashDisplayable
HomeLocationSearchProvider
AllPartyHeaderViewBuilder
EnhancedDispatchingPhaseCountdown
StaticAutoStopParameters
SuggestionCalloutView
LocationCollectionWorker
OffTripNavigationCancelSectionInteractor
TrustedContactsPluginContext
PaddingView
RewardsRiderMenuSubtitleStream
EmptyHelpRewardsPhoneSupportCell
AgendaBuilder
HubMessagingActionHandlerPluginContextImpl
ProtoViewController
FormTimeFormatter
EnhancedDispatchingPhaseRoutelineZoomTransition
UberBankDescriptorBuilder
ModeStreamNever
JumpOpsSharedMutableSelectedMapMarkerStream
AttributedStringUtility
ReferralsDashboardInviteSuggestedContactCell
ChooseBoletoInputMethodBuilder
ConversationsListEmptyPluginPoint
TextFieldComponent
BadgeLeadingButtonAccessoryViewPluginFactory
CountryTableViewHeader
DeliveryLocationDetailsBuilder
CompositeCardPresenter
TransitTicketSuccess
DidSelectOrSkipDestinationToPickupStepEventHandler
UberMoneyChangePinBuilder
ConfirmableRegistry
TriggerWebViewAction
VehicleConfirmationDialogBuilder
TableWidgetView
DeliveryLocationBuilder
LegacySocialProfilesStream
NavigationControllerRouter
ContactsPermissionPrimerBuilder
WalletDemoManageAddonProvider
HelpWorkflowUserInputModelSupportNodeReference
ConfirmFlowStep
BatchingDispatchingMapRouter
LegalTextFooterCell
AuditInteractionRecordGenerator
Adyen3DS2InitializeParameters
RewardsTierProgressBarViewV2
SafeCashDispatchWhitelistedPaymentProfileStream
RewardsHubFooterView
PersistedArrearsV2Stream
SubscriptionDisposing
EnhancedDispatchingPhaseProgress
EnhancedDispatchingPhasePickupZoom
EnhancedDispatchingPhaseAck
EnhancedDispatchingPhaseRouteline
HeliumPickupMapLayerComponentBuilder
ReviewBoletoDetailsAndPayBuilder
SamplingBackgroundProtection
MonitoringKeysTripDetailsCards
ProfileStream
SingleSignOnRequestConstants
BrokenViewController
EatsWebLaunchEventManagingMock
DataSyncClientImpl
FillMapRegion
PlaceholderTheme
PaypalGrantBuilder
MasabiEnvironmentConfigs
ShareMessageWorkflowPluginFactory
SavedPlacesBuilder
RentalQRScannerHelper
PluginTripDetailsRowSlotConfigImpl
SelectPaymentAddonProviderImpl
MobileStudioOverlayView
SingleSignOnPayload
USnapAnalyticsProvidingFixture
PassRefundTextAreaView
BaseCollectionViewController
NewSnapCollectionViewContentOffsetCalculator
UpiClientPaymentMethodDisplayable
LegacySocialProfilesServiceBuilder
AuditInteractionStream
EarningsSummaryTripHistoryProvider
SupportTreeHelper
ListStyleGuideViewController
SelectableListFooterCollectionViewCell
AddPaymentAction
EMobilityHelpRewardsPhoneCell
ScopeDisposing
ContactsPermissionsManager
EnhancedDispatchingPhaseDropoffZoom
RatingCelebrationPresentationController
AggregationFunction
TransitFirstMileEnhancedDestinationTextSearchWorkerPluginFactory
ProductRoundedIconView
HomeEntryContainerView
DummyCachedExperiments
ImpressionAuditEventTransformer
SafetyToolkitPluginPointManager
JumpOpsDropoffHubMapMarker
UGCPhotoUploadBuilder
PrivacySettingsUsersServiceBuilder
UGCPhotoUploadViewController
DeliveryLocationRouter
ContactsPermissionPrimerViewController
OldRootComponent
ChooseBoletoInputMethodInteractor
PaypalGrantRouter
TransitFirstMileEnhancedDestinationTextSearchComponent
ShowGrantPaymentStepPluginAdapter
EMobilityCameraConfirmationRouter
EmptyHomeSearchResultEntity
UberMoneyChangePinRouter
TerminalInfo
ExpenseProviderListDataSource
ScreenflowNumberListResultFlowComponent
DeliveryLocationDetailsInteractor
SubscriptionDisposing
LowBalanceAlertView
PaypalGrantComponent
AccountSettingsFlowRouter
RentalContactProviderInteractor
ParameterKeyObjC
AccountSettingsFlowComponent
AgendaComponent
ListStyleGuideViewController
PaypalGrantInteractor
SavedPlacesComponent
RxNotifiyingBoundedDeque
RentalContactProviderViewController
UberMoneyUpdateAddressComponent
HubMessagingDeeplinkRideRequestHubActionHandlerPluginFactory
UberBankDescriptor
DeliveryLocationDetailsViewController
AccountSettingsFlowInteractor
AppendMetricsSpanInterceptor
ReviewBoletoDetailsAndPayInteractor
DispatchingSecondaryComponent
ContactsPermissionPrimerInteractor
ScopeDisposing
DispatchingSecondaryInteractor
AggregationFunction
HelpTripSummaryCell
ScreenflowBooleanResultFlowComponent
ScheduledRidesTimePickerRouter
DonateScreenflowBuilder
UberTracer
ButtonCardCell
HelpHomeMessagesCardPlugin
ProfileIntroView
SynchronizedUnboundedDeque
ChooseBoletoInputMethodViewController
SavedPlacesInteractor
EmojisSurveyStepAlertView
ShareMessageWorkflow
PaymentAsynchronousPluginPoint
ScreenflowNumberResultFlowComponent
ShowGrantPaymentStepComponent
ScheduledRidesTimePickerComponent
ClientSideTreatments
DispatchingSecondaryViewController
WaitTimeTripIssuesListPluginFactory
UberMoneyChangePinComponent
OldRootRouter
Component_DEPRECATED
VehicleConfirmationDialogInteractor
SampleAppSystemPermissionAnalyticsReporter
PaymentOnboardingInteractor
FreeRidesOpportunityButton
ScheduledRidesTimePickerInteractor
UGCCollectionBuildResultImp
SafeViewController
UberCashAddFundsAutoRefillComponent
SelectedProductBottomSheetViewProvider
ContactsPermissionPrimerPresenter
FinancialAccountDetailsComponent
ScheduledRidesHomeEntryFlowComponent
ChooseBoletoInputMethodRouter
PaymentWallPluginFactory
UGCPhotoUploadResultStream
MockedTasksStream
HubMessagingWebPageRideRequestHubActionHandlerPluginFactory
HelpHomeIssueListCardPlugin
UGCPhotoUploadInteractor
ContactsPermissionPrimerPreferences
VehicleConfirmationDialogViewController
adrListener
UberCashAddFundsAutoRefillRouter
AuthenticationAppDelegate
BrokenViewController
ReviewBoletoDetailsAndPayViewController
UGCPhotoCollectionDummy
AddPaymentAction
OldRootInteractor
DirectLineInfoRequestWorker
ShimAppDelegate
SavedPlacesRouter
VehicleConfirmationDialogRouter
DefaultTripIssuesListPluginFactory
RentalContactProviderRouter
DispatchingSecondaryRouter
UGCCollectionInteractor
PaymentOnboardingViewController
ContactsPermissionPrimerRouter
UnsafeViewController
PaymentOnboardingRouter
DeliveryLocationDetailsComponent
ReviewBoletoDetailsAndPayRouter
EMobilityCameraConfirmationComponent
EMobilityCameraConfirmationViewController
DataSyncPatcher
DeliveryLocationInteractor
AccountSettingsFlowViewController
UberMoneyUpdateAddressViewController
PaymentOnboardingComponent
UberMoneyUpdateAddressInteractor
FinancialAccountDetailsRouter
FinancialAccountDetailsViewController
ReviewBoletoDetailsAndPayComponent
ContactsPermissionPrimerComponent
VehicleConfirmationDialogComponent
UberCashAddFundsAutoRefillInteractor
UberMoneyUpdateAddressRouter
WalletDemoManageAddonProvider
DataSyncStore
UberMoneyChangePinViewController
UGCCollectionViewController
ThumbRatingView
SavedPlacesViewController
ChooseBoletoInputMethodComponent
UberMoneyChangePinInteractor
UGCPhotoUploadRouter
DeliveryLocationComponent
ScheduledRidesTimePickerPresenter
DeliveryLocationDetailsRouter
ScreenflowStringListResultFlowComponent
DataSyncAcker
UGCCollectionRouter
FinancialAccountDetailsInteractor
MyView2
CashDescriptor
GreenDotDescriptor
GoBankDescriptor
BankAccountDescriptor
BankAccountDescriptorComponent
ZaakpayDescriptor
PaypalDescriptor
BraintreeDescriptor
ConnectContactsMetadata
GreenDotDescriptorComponent
PaytmDescriptor
UpiDescriptor
GoBankDescriptorComponent
ApplePayDescriptor
"""
