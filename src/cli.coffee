checks = require "#{__dirname}/checks"
fs     = require 'fs'
meta   = require "#{__dirname}/../package.json"
parser = require "#{__dirname}/parser"
utils  = require "#{__dirname}/utils"

usage = ->
  console.log "Dockerlint #{meta["version"]}\n\n
  \tusage: dockerlint [-h] [-dp] [-f Dockerfile]"
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

  # If no file is explicitly passed with -f, try the first
  # unbound argument and fallback to 'Dockerfile'
  dockerfile = args.file || args._[0] || 'Dockerfile'

  # Ensure that 'dockerfile' is a String; if the filename happens to be
  # an integer (e.g. '1'), lstat() and other cannot handle it.
  dockerfile = dockerfile.toString()

  unless fs.existsSync dockerfile
    utils.log "FATAL", "Cannot open #{dockerfile}."

  if not fs.lstatSync(dockerfile).isFile()
    utils.log "FATAL", "#{dockerfile} is not a file."

  rules = parser.parser(dockerfile)

  if args.debug
    utils.log 'DEBUG', rules

  ok = true
  for check in checks.all
    if checks[check](rules) is 'failed'
      ok = false

  report(dockerfile, ok)