final class TripDetailsComponent: PluginizedComponent<TripDetailsDependency, TripDetailsPluginExtension, TripDetailsNonCoreComponent> {

    let cellType: UICollectionViewCell.Type = EmptySpaceCardCell.self
    var cellReuseId: String { return OmgEmptySpaceCardCell.reuseId }

    func foo() {
        self.performSegue(withIdentifier: DeviceSensorsViewController.kDeviceSensorsBeaconTimerViewControllerSegue, sender: nil)
        guard let localcell = cell as? BtwEmptySpaceCardCell else {return}
    }
}
