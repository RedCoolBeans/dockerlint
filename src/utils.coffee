args = require('subarg')(process.argv.slice(2), alias:
  d: 'debug'
  f: 'file'
  h: 'help'
  p: 'pedantic')
sty  = require 'sty'

String::beginsWith ?= (s) -> @[...s.length] is s
String::endsWith   ?= (s) -> s is '' or @[-s.length..] is s

# Return false if empty, false otherwise.
exports.notEmpty = (s) -> not (s.trim() == '')

# log a message to the user, with increasing levels of importance:
# DEBUG, INFO, WARN, ERROR and FATAL (for non-checks)
exports.log = (level, msg) ->
  switch level
    when 'FATAL', 5
      console.error "#{sty.red 'ERROR'}: #{msg}"
      process.exit 1
    when 'ERROR', 4
      console.error "#{sty.red 'ERROR'}: #{msg}"
    when 'WARN', 3
      console.warn "#{sty.red 'WARN'}:  #{msg}"
      process.exit 1 if args.pedantic
    when 'INFO', 2
      console.log "#{sty.green 'INFO'}: #{msg}"
    else
      process.stdout.write "#{sty.blue 'DEBUG'}:"
      console.dir msg
