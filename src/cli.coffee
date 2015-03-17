checks = require "#{__dirname}/checks"
fs     = require 'fs'
meta   = require "#{__dirname}/../package.json"
parser = require "#{__dirname}/parser"
utils  = require "#{__dirname}/utils"

usage = ->
  console.log "Dockerlint #{meta["version"]}\n\n
  \tusage: dockerlint [-hp] Dockerfile"
  process.exit 0

report = (dockerfile, ok) ->
  if ok
    console.log ""
    utils.log "INFO", "#{dockerfile} is OK.\n"
  else
    console.log ""
    utils.log "FATAL", "#{dockerfile} failed.\n"

exports.run = (args) ->
  if args.help
    do usage

  # Save the filename from the first of the unbound arguments.
  unless args.file?
    utils.log 'FATAL', 'No Dockerfile specified with -f'
  else
    dockerfile = args.file

  unless fs.existsSync dockerfile
    utils.log "FATAL", "Cannot open #{dockerfile}."

  rules = parser.parser(dockerfile)

  if args.debug
    utils.log 'DEBUG', rules

  ok = true
  for check in checks.all
    if checks[check](rules) is 'failed'
      ok = false

  report(dockerfile, ok)