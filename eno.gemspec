require_relative './lib/eno/version'

Gem::Specification.new do |s|
  s.name        = 'eno'
  s.version     = Eno::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Eno: Eno is Not an ORM'
  s.author      = 'Sharon Rosner'
  s.email       = 'ciconia@gmail.com'
  s.files       = `git ls-files`.split
  s.homepage    = 'http://github.com/digital-fabric/eno'
  s.metadata    = {
    "source_code_uri" => "https://github.com/digital-fabric/eno"
  }
  s.rdoc_options = ["--title", "eno", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md"]
  s.require_paths = ["lib"]

  s.add_runtime_dependency      'modulation', '0.18'
  s.add_development_dependency  'pg',         '1.1.3'
  s.add_development_dependency  'sqlite3',    '1.3.13'
end
