require "yaml"
require "set"
require "json"

require "./domain"
require "./inventory"
require "./transport"
require "./connectivity"
require "./audit"
require "./updates"
require "./updates/state"
require "./cli"

# HomeLabManager is a safety-first CLI for homelab host management.
module HomeLabManager
  VERSION = "0.1.0"
end
