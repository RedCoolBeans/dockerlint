args = require('subarg') process.argv.slice(2), alias:
             d: 'debug'
             f: 'file',
             h: 'help',
             p: 'pedantic'
cli = require '../lib/cli'

cli.run args
