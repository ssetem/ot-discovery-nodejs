class DiscoveryError extends Error
  constructor:(@update) ->
    @message = @messagePrefix + JSON.stringify(@update)
    Error.captureStackTrace(@, @constructor)

class DiscoveryConnectError extends DiscoveryError
  constructor:(@update) ->
    @messagePrefix = "Unabled to initiate discovery: "
    super

class DiscoveryFullUpdateError extends DiscoveryError
  constructor:(@update) ->
    @messagePrefix = "Expecting a full update: "
    super

module.exports = {
  DiscoveryError
  DiscoveryConnectError
  DiscoveryFullUpdateError
}