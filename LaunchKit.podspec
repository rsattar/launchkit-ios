Pod::Spec.new do |s|
  s.name             = "LaunchKit"
  s.version          = "0.3.5"
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
  s.private_header_files = 'LaunchKit/Classes/ThirdParty/**/*.h'

  s.subspec 'Default' do |default|
    default.exclude_files = 'LaunchKit/Classes/UI/Components/UIView+LKAdditions.h'
  end
  s.subspec 'Internal' do |internal|
  end
  s.default_subspec = 'Default'

  s.resource_bundles = {
    'LaunchKitResources' => ['LaunchKit/Assets/*.xcassets']
  }
  s.preserve_paths = 'LaunchKit/Scripts/**/*'

  # s.public_header_files = 'LaunchKit/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.libraries = 'z'
end
