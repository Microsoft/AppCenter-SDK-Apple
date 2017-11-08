Pod::Spec.new do |s|
  s.name              = 'AppCenter'
  s.version           = '0.14.1'

  s.summary           = 'App Center is mission control for mobile apps. Get faster release cycles, higher-quality apps, and the insights to build what users want.'
  s.description       = <<-DESC
                      App Center is mission control for mobile apps.
                      Get faster release cycles, higher-quality apps, and the insights to build what users want.

                      The App Center SDK uses a modular architecture so you can use any or all of the following services: 

                      1. App Center Analytics:
                      App Center Analytics helps you understand user behavior and customer engagement to improve your app. The SDK automatically captures session count, device properties like model, OS version, etc. You can define your own custom events to measure things that matter to you. All the information captured is available in the App Center portal for you to analyze the data.

                      2. App Center Crashes:
                      App Center Crashes will automatically generate a crash log every time your app crashes. The log is first written to the device's storage and when the user starts the app again, the crash report will be sent to App Center. Collecting crashes works for both beta and live apps, i.e. those submitted to the App Store. Crash logs contain valuable information for you to help fix the crash.

                      3. App Center Distribute:
                      App Center Distribute will let your users install a new version of the app when you distribute it via the App Center. With a new version of the app available, the SDK will present an update dialog to the users to either download or postpone the new version. Once they choose to update, the SDK will start to update your application. This feature will NOT work if your app is deployed to the app store.

                      4. App Center Push:
                      App Center Push enables you to send push notifications to users of your app from the App Center portal. You can also segment your user base based on a set of properties and send them targeted notifications.

                        DESC

  s.homepage          = 'https://appcenter.ms'
  s.documentation_url = "https://docs.microsoft.com/en-us/appcenter/sdk"

  s.license           = { :type => 'MIT',  :file => 'AppCenter-SDK-Apple/LICENSE'}
  s.author            = { 'Microsoft' => 'appcentersdk@microsoft.com' }

  s.platform          = :ios, '8.0'
  s.source = { :http => "https://github.com/microsoft/app-center-sdk-ios/releases/download/#{s.version}/AppCenter-SDK-Apple-#{s.version}.zip" }

  s.preserve_path = "AppCenter-SDK-Apple/LICENSE"

  s.default_subspecs = 'Analytics', 'Crashes'

  s.subspec 'Core' do |ss|
    ss.frameworks = 'Foundation', 'SystemConfiguration', 'CoreTelephony', 'UIKit'
    ss.vendored_frameworks = "AppCenter-SDK-Apple/iOS/AppCenter.framework"
    ss.libraries = 'sqlite3'
  end

 s.subspec 'Analytics' do |ss|
    ss.frameworks = 'Foundation', 'UIKit'
    ss.dependency 'AppCenter/Core'
    ss.vendored_frameworks = "AppCenter-SDK-Apple/iOS/AppCenterAnalytics.framework"
  end

  s.subspec 'Crashes' do |ss|
    ss.frameworks = 'Foundation'
    ss.libraries = 'z', 'c++'
    ss.dependency 'AppCenter/Core'
    ss.vendored_frameworks = "AppCenter-SDK-Apple/iOS/AppCenterCrashes.framework"
  end

 s.subspec 'Distribute' do |ss|
    ss.frameworks = 'Foundation', 'UIKit'
    ss.weak_frameworks = 'SafariServices'
    ss.dependency 'AppCenter/Core'
    ss.resource_bundle = { 'AppCenterDistributeResources' => ['AppCenter-SDK-Apple/iOS/AppCenterDistributeResources.bundle/*.lproj'] }
    ss.vendored_frameworks = "AppCenter-SDK-Apple/iOS/AppCenterDistribute.framework"
 end

 s.subspec 'Push' do |ss|
    ss.frameworks = 'Foundation', 'UIKit'
    ss.weak_frameworks = 'UserNotifications'
    ss.dependency 'AppCenter/Core'
    ss.vendored_frameworks = "AppCenter-SDK-Apple/iOS/AppCenterPush.framework"
 end

end
