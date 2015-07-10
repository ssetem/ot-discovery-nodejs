
class ConsoleLogger

  constructor:()->
    @console = console

  log:(level, args...)->
    @console[level]?.apply(@console, args)

module.exports = new ConsoleLogger()