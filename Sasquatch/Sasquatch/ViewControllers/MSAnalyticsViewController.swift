import UIKit

class MSAnalyticsViewController: UITableViewController, AppCenterProtocol {

  @IBOutlet weak var enabled: UISwitch!
  @IBOutlet weak var eventName: UITextField!
  @IBOutlet weak var pageName: UITextField!
  @IBOutlet weak var pause: UIButton!
  @IBOutlet weak var resume: UIButton!

  var appCenter: AppCenterDelegate!
  var eventPropertiesSection: EventPropertiesTableSection!
  @objc(analyticsResult) var analyticsResult: MSAnalyticsResult? = nil

  private var kEventPropertiesSectionIndex: Int = 2
  private var kResultsPageIndex: Int = 2

  override func viewDidLoad() {
    eventPropertiesSection = EventPropertiesTableSection(tableSection: kEventPropertiesSectionIndex, tableView: tableView)
    super.viewDidLoad()
    tableView.estimatedRowHeight = tableView.rowHeight
    tableView.rowHeight = UITableViewAutomaticDimension
    tableView.setEditing(true, animated: false)
    
    // Disable results page.
    #if !ACTIVE_COMPILATION_CONDITION_PUPPET
    let cell = tableView.cellForRow(at: IndexPath(row: kResultsPageIndex, section: 0))
    cell?.isUserInteractionEnabled = false
    cell?.contentView.alpha = 0.5
    #endif
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.enabled.isOn = appCenter.isAnalyticsEnabled()
    
    // Make sure the UITabBarController does not cut off the last cell.
    self.edgesForExtendedLayout = []
  }

  @IBAction func trackEvent() {
    guard let name = eventName.text else {
      return
    }
    let eventProperties = eventPropertiesSection.eventProperties()
    if (MSTransmissionTargets.shared.defaultTargetShouldSendAnalyticsEvents()) {
      if let properties = eventProperties as? MSEventProperties {

        // The AppCenterDelegate uses the argument label "withTypedProperties," but the underlying swift API simply uses "withProperties."
        appCenter.trackEvent(name, withTypedProperties: properties)
      } else if let dictionary = eventProperties as? [String: String] {
        appCenter.trackEvent(name, withProperties: dictionary)
      } else {
        appCenter.trackEvent(name)
      }
    }
    for targetToken in MSTransmissionTargets.shared.transmissionTargets.keys {
      if MSTransmissionTargets.shared.targetShouldSendAnalyticsEvents(targetToken: targetToken) {
        let target = MSTransmissionTargets.shared.transmissionTargets[targetToken]
        if let properties = eventProperties as? MSEventProperties {
          target!.trackEvent(name, withProperties: properties)
        } else if let dictionary = eventProperties as? [String: String] {
          target!.trackEvent(name, withProperties: dictionary)
        } else {
          target!.trackEvent(name)
        }
      }
    }
  }

  @IBAction func trackPage() {
    guard let name = eventName.text else {
      return
    }
    appCenter.trackPage(name)
  }

  @IBAction func enabledSwitchUpdated(_ sender: UISwitch) {
    appCenter.setAnalyticsEnabled(sender.isOn)
    sender.isOn = appCenter.isAnalyticsEnabled()
  }

  @IBAction func pause(_ sender: UIButton) {
    appCenter.pause()
  }

  @IBAction func resume(_ sender: UIButton) {
    appCenter.resume()
  }

  func enablePauseResume(enable: Bool) {
    pause.isEnabled = enable
    resume.isEnabled = enable
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let destination = segue.destination as? MSAnalyticsResultViewController {
      destination.analyticsResult = analyticsResult
    }
  }

  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    eventPropertiesSection.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
  }

  override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
    if indexPath.section == kEventPropertiesSectionIndex {
      return eventPropertiesSection.tableView(tableView, editingStyleForRowAt: indexPath)
    }
    return .delete
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if indexPath.section == kEventPropertiesSectionIndex && eventPropertiesSection.isInsertRow(indexPath) {
      self.tableView(tableView, commit: .insert, forRowAt: indexPath)
    }
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == kEventPropertiesSectionIndex {
      return eventPropertiesSection.tableView(tableView, numberOfRowsInSection: section)
    }
    return super.tableView(tableView, numberOfRowsInSection: section)
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableViewAutomaticDimension
  }

  /**
   * Without this override, the default implementation will try to get a table cell that is out of bounds
   * (since they are inserted/removed at a slightly different time than the actual data source is updated).
   */
  override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
    return 0
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    if indexPath.section == kEventPropertiesSectionIndex {
      return eventPropertiesSection.tableView(tableView, canEditRowAt:indexPath)
    }
    return false
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return false
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == kEventPropertiesSectionIndex {
      return eventPropertiesSection.tableView(tableView, cellForRowAt:indexPath)
    }
    return super.tableView(tableView, cellForRowAt: indexPath)
  }
}
