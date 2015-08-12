ConsoleLogger = require("#{srcDir}/ConsoleLogger")



describe "ConsoleLogger", ->


  it "should exist", ->
    expect(ConsoleLogger).to.exist

  it "should log", ->
    mockConsole = ConsoleLogger.console = {
      logs:[]
      debug:(args...)->
        @logs.push ["debug"].concat(args)
      error:(args...)->
        @logs.push ["error"].concat(args)
    }

    ConsoleLogger.log "debug", "1", "2"
    ConsoleLogger.log "error", "oh", "no"
    ConsoleLogger.log "nosuchmethod", "oh", "no"
    ConsoleLogger.log "debug"
    ConsoleLogger.log "nosuchmethod"

    expect(mockConsole.logs).to.deep.equal [
      [ 'debug', '1', '2' ],
      [ 'error', 'oh', 'no' ],
      ['debug']
    ]






