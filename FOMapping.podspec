Pod::Spec.new do |s|
  s.name = 'FOMapping'
  s.version = '1.0.0'
  s.summary = 'A simple ORM extension of FMDB.'
  s.homepage = 'https://github.com/yfben/FOMapping'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'Ben YF Chen' => 'benxyz.chen@gmail.com' }
  s.source = { :git => 'https://github.com/yfben/FOMapping.git', :tag => s.version.to_s }
  s.source_files  = 'FOObject/*.{h,m}'
  s.library = 'sqlite3'
  s.requires_arc = true
  s.dependency 'FMDB', '~> 2.5'
  s.ios.deployment_target = '7.0'
end