
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "iiif_to_jekyll/version"

Gem::Specification.new do |spec|
  spec.name          = "iiif_to_jekyll"
  spec.version       = IiifToJekyll::VERSION
  spec.authors       = ["Emory Center for Digital Scholarship"]
  spec.email         = ["benwbrum@gmail.com", "saracarl@gmail.com"]

  spec.summary       = "Gem for converting a Readux-generated IIIF manifest to a static Jeckyll site."
#  spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "https://github.com/ecds/iiif-to-jekyll"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/ecds/iiif-to-jekyll"
    spec.metadata["changelog_uri"] = "https://github.com/ecds/iiif-to-jekyll/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
#  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.executables   += ["iiif_to_jekyll"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"	
  spec.add_development_dependency "pry-byebug"

  spec.add_runtime_dependency "iiif-presentation", "~> 0.2.0"
  spec.add_runtime_dependency "openssl"
end
