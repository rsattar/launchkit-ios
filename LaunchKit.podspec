Pod::Spec.new do |s|
  s.name             = "LaunchKit"
  s.version          = "2.1.4"
  s.summary          = "Useful tools you need to launch your app."
  s.description      = <<-DESC
                       We provide tools for launching your app like
                       measuring app installs, capturing light data
                       about how the app is being used, etc.
                       DESC
  s.homepage         = "https://github.com/LaunchKit/launchkit-ios"
  s.license          = 'Apache 2.0'
  s.author           = { "Cluster Labs, Inc." => "info@getcluster.com" }
  s.source           = { :git => "https://github.com/LaunchKit/launchkit-ios.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/launchkit'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.default_subspec = 'LaunchKit'

  s.subspec 'LaunchKit' do |launchkit|
    launchkit.source_files = 'LaunchKit/Classes/**/*.{h,m,c}'
    launchkit.private_header_files = 'LaunchKit/Classes/ThirdParty/**/*.h'
    launchkit.exclude_files = 'LaunchKit/Classes/**/Private/*'
  end

  s.subspec 'Internal' do |internal|
    internal.source_files = 'LaunchKit/Classes/**/*.{h,m,c}'
    internal.private_header_files = 'LaunchKit/Classes/ThirdParty/**/*.h'
    internal.exclude_files = 'LaunchKit/Classes/**/Public/*'
  end

  s.resource_bundles = {
    'LaunchKitResources' => ['LaunchKit/Assets/*.xcassets']
  }
  s.preserve_paths = 'LaunchKit/Scripts/**/*'

  s.libraries = 'z'
end
