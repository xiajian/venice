require 'venice/version'
require 'venice/profile'
require 'venice/client'
require 'venice/in_app_receipt'
require 'venice/receipt'
require 'venice/pending_renewal_info'

module Venice
  autoload :Configure, File.expand_path('../venice/configure', __FILE__)
  
  class << self
    include Configure
  end
end
