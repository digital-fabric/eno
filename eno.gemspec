require_relative './lib/eno/version'

Gem::Specification.new do |s|
  s.name        = 'eno'
  s.version     = Eno::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Eno: Eno is Not an ORM'
  s.author      = 'Sharon Rosner'
  s.email       = 'ciconia@gmail.com'
  s.files       = `git ls-files README.md CHANGELOG.md lib`.split
  s.homepage    = 'http://github.com/digital-fabric/eno'
  s.metadata    = {
    "source_code_uri" => "https://github.com/digital-fabric/eno"
  }
  s.rdoc_options = ["--title", "eno", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md"]
  s.require_paths = ["lib"]

  s.add_runtime_dependency      'modulation',     '0.18'
end
