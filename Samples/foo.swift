
let rewardsBottomButtonFactoryCreateButtonHandler: ((_ analyticsID: AnalyticsID, _ themeStream: ThemeStream) -> RewardsBottomButton)? = { (_, _) -> RewardsBottomButton in
    let rewardsBottomButtonMock = RewardsBottomButtonMock(button: Button__Deprecated(analyticsID: .value("test"), themeStream: StaticThemeStream.forHelix))
    rewardsBottomButtonMock.installHandler = { view in
        view.addSubview(rewardsBottomButtonMock.button)

        let make = rewardsBottomButtonMock.button.snp.beginRemakingConstraints()
        make.leading.trailing.bottom.equalToSuperview()
        make.endRemakingConstraints()
    }
    rewardsBottomButtonMock.getControlHandler = {
        return rewardsBottomButtonMock.button
    }
    return rewardsBottomButtonMock
}


final class TripDetailsComponent: PluginizedComponent<TripDetailsDependency, TripDetailsPluginExtension, TripDetailsNonCoreComponent> {
    private var interactor: UserIdentityFlow.IdentityVerificationIntroInteractor!

    private let presenter = UserIdentityFlow.IdentityVerificationIntroPresentableMock()

    

//    let mapView = UberMSDMapViewableMock(camera: MSDCameraPosition(target: CLLocationCoordinate2D(latitude: 33, longitude: -77), tilt: 1, bearing: 7, zoom: 9))


//    let cellType: UICollectionViewCell.Type = EmptySpaceCardCell.self
//    var cellReuseId: String { return OmgEmptySpaceCardCell.reuseId }
//
//    func foo() {
//        self.performSegue(withIdentifier: DeviceSensorsViewController.kDeviceSensorsBeaconTimerViewControllerSegue, sender: nil)
//        guard let localcell = cell as? BtwEmptySpaceCardCell else {return}
//    }
}
