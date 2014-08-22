# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis_open3/version'

Gem::Specification.new do |spec|
  spec.name          = "redis_open3"
  spec.version       = RedisOpen3::VERSION
  spec.authors       = ["Tyler Hartland"]
  spec.email         = ["tyler.hartland@code42.com"]
  spec.summary       = %q{Use Open3 like sematics to pass data through Redis.}
  # spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'rspec', '~> 3.0.0'

  spec.add_runtime_dependency 'redis', '~> 3.1.0'
end
