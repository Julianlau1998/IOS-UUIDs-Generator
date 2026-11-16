platform :ios, '26.0'

target 'UUIDs Generator' do
  use_frameworks!

  pod 'Google-Mobile-Ads-SDK'
  pod 'GoogleUserMessagingPlatform'
end

post_install do |installer|
  # Older pods declare deployment targets that current Xcode versions no longer support.
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
    end
  end
end
