Pod::Spec.new do |s|
  s.name             = "LaunchKit"
  s.version          = "0.1.1"
  s.summary          = "Useful tools you need to launch your app."
  s.description      = <<-DESC
                       We provide tools for launching your app like
                       measuring app installs, capturing light data
                       about how the app is being used, etc.
                       DESC
  s.homepage         = "https://github.com/clusterinc/launchkit-ios"
  s.license          = 'MIT'
  s.author           = { "Cluster Labs, Inc." => "info@getcluster.com" }
  s.source           = { :git => "https://github.com/clusterinc/launchkit-ios.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/launchkit'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'LaunchKit/Classes/**/*.{h,m,c}'
  s.resource_bundles = {
    'LaunchKitResources' => ['LaunchKit/Assets/*.xcassets']
  }

  # s.public_header_files = 'LaunchKit/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
end
