os    = require 'os'
path  = require 'path'
utils = require "#{__dirname}/utils"

args = require('subarg')(process.argv.slice(2), alias:
  d: 'debug'
  f: 'file'
  h: 'help'
  p: 'pedantic')

if args.pedantic
  exports.pedantic_ret = 'failed'
  exports.pedantic_severity = 'ERROR'
else
  exports.pedantic_ret = 'warning'
  exports.pedantic_severity = 'WARN'

exports.all = [
  'arg',
  'from_first',
  'no_empty_tag',
  'no_empty_digest',
  'json_array_brackets',
  'json_array_even_quotes',
  'json_array_format',
  'env',
  'recommended_exec_form',
  'add',
  'multiple_entries',
  'sudo',
  'absolute_workdir',
  'onbuild_copyadd',
  'onbuild_disallowed',
  'label_no_empty_value',
  'variable_use',
  'no_trailing_spaces'
]

# Match $VAR, ${VAR}, and ${VAR:-default}
# FIXME: does not handle \$VAR escaping
# Variable name 'VAR' is Group 1 or Group 2
exports.varPattern = ///
  (?:       # Don't capture, just match
  \$        # Dollar sign to start the variable
  (?:       # Don't capture, just group
  ([\w]+)   # Match one or more word characters (greedy), this is the variable name like VAR
  |         # Or
  \{        # Match the starting brace for variables like ${VAR}
  (\w+)     # Match one or more word characters (greedy), this is the variable name like VAR
  .*?\}     # Match characters after variable name to handle ${VAR} and ${VAR:-default}
  ))        # End the non-capturing groups
///g        # Global match to find all variables in a string

# Cache the ARG variables for lookup
exports.arg = []
# Cache the ENV variables for lookup
exports.env = []

Array::filter = (func) -> x for x in @ when func(x)

# Returns all rules for `instruction`
exports.getAll = (instruction, rules) ->
  rules.filter (r) -> r.instruction is instruction

# Returns all rules except those for `instruction`.
exports.getAllExcept = (instruction, rules) ->
  rules.filter (r) -> r.instruction isnt instruction

# Return effective available variables from ARG and ENV
exports.getAllVariables = (rules) ->
  this.arg(rules)
  this.env(rules)
  # ENV overrides ARG https://docs.docker.com/engine/reference/builder/#using-arg-variables
  utils.merge(exports.arg, exports.env)

# Merge variables from rule (ARG, ENV) with provided object
exports.mergeVariables = (o, rule) ->
  for argument in rule.arguments
    if argument.split(' ')[0].match(/(\w+)=([^\s]+)/)
      for pair in argument.split(' ')
        p = pair.split(/(\w+)=([^\s]+)/)
        o[p[1]] = p[2]
    else
      env = argument.match(/^(\S+)\s(.*)/)
      if env
        env = env.slice(1)
      else
        return 'failed'
      if env[0] && env[1]
        o[env[0]] = env[1]
      else
        return 'failed'
  return 'ok'

# Check that all variables in a string are defined
exports.variablesDefined = (vars, s) ->
  while match = exports.varPattern.exec(s)
    m = match[1] || match[2]
    unless vars[m]
      #utils.log 'DEBUG', "Undefined variable match #{match} within #{s}"
      return 'failed'
  return 'ok'

# Replace all variables with values
exports.variablesReplace = (vars, s) ->
  s.replace exports.varPattern, (match, g1, g2, offset, str) ->
    m = g1 || g2
    if vars[m]
      return str.replace(match,vars[m])
    else
      #utils.log 'DEBUG', "Undefined variable replacement #{match} within #{str}"
      return str

# FROM should be the first non-comment instruction in the Dockerfile
# it may be preceeded by ARG
# Reports: ERROR
exports.from_first = (rules) ->
  non_comments = this.getAllExcept('comment', rules)
  first = non_comments[0]

  if first.instruction isnt 'FROM'
    unless first.instruction is 'ARG'
      utils.log 'ERROR', "First instruction must be 'FROM', is: #{first.instruction}"
      return 'failed'
  return 'ok'

# If no tag is given to the FROM instruction, latest is assumed. If the used
# tag does not exist, an error will be returned.
# Reports: ERROR if tag is empty
exports.no_empty_tag = (rules) ->
  from = this.getAll('FROM', rules)
  for rule in from
    # FROM lines can only have a single argument, so use [0].
    if rule.arguments[0].match /:/
      [image, tag] = rule.arguments[0].split ':'
      unless utils.notEmpty tag
        utils.log 'ERROR', "Tag must not be empty for \"#{image}\" on line #{rule.line}"
        return 'failed'
  return 'ok'

# If no digest is given to the FROM instruction an error will be returned when
# a digest is expected.
# Reports: ERROR if digest is empty
# Docker: 1.6
exports.no_empty_digest = (rules) ->
  from = this.getAll('FROM', rules)
  for rule in from
    # FROM lines can only have a single argument, so use [0].
    if rule.arguments[0].match /@/
      [image, digest] = rule.arguments[0].split '@'
      unless utils.notEmpty digest
        utils.log 'ERROR', "Digest must not be empty for \"#{image}\" on line #{rule.line}"
        return 'failed'
  return 'ok'

# The exec form is parsed as a JSON array, which means that you must use
# double-quotes (") around words not single-quotes (').
# Reports: ERROR
exports.json_array_format = (rules) ->
  for i in [ 'CMD', 'ENTRYPOINT', 'RUN', 'VOLUME' ]
    rule = this.getAll(i, rules)
    for r in rule
      errmsg = "Arguments to #{i} in exec form must not contain single quotes on line #{r.line}"
      for argument in r.arguments
        # Check if we're dealing with Array notation
        if argument.match /^\[.*\]/
          # Break the literal array into it's logical components
          for arg in argument.split(/,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)/, -1)
            if not arg.trim().match /^\[?(\s+)?\".*\"(\s+)?\]?$/
              utils.log 'ERROR', errmsg
              return 'failed'
  return 'ok'

# Ensure the exec form contains a balanced number of double quotes.
# Reports: ERROR
exports.json_array_even_quotes = (rules) ->
  for i in [ 'CMD', 'ENTRYPOINT', 'RUN', 'VOLUME' ]
    rule = this.getAll(i, rules)
    for r in rule
      # First turn all the arguments into a single string so that we have the
      # full overview of the arguments which we then split on \". If the number
      # of elements is uneven `quotes` will be true and thus we have an invalid
      # argument list. Otherwise we get an even number of elements
      # (for an even number modulo 2 is 0).
      quotes = r.arguments.join(' ').split('"')
      unless (quotes.length) % 2
        utils.log 'ERROR', "Odd number of double quotes on line #{r.line}"
        return 'failed'
  return 'ok'

# Ensure the exec form contains one opening and one closing square bracket.
# Reports: ERROR
exports.json_array_brackets = (rules) ->
  for i in [ 'CMD', 'ENTRYPOINT', 'RUN', 'VOLUME' ]
    rule = this.getAll(i, rules)
    for r in rule
      # First make sure we're actually dealing with the exec form (not ignoring position)
      unless r.arguments[0].match(/(^\s*\[)|(\]\s*$)/g)
        continue

      # Check if this is a valid JSON array
      try
        # parse to JSON
        arg2json = JSON.parse r.arguments.join(' ')
        # count number of entries in main array that are arrays
        nArray = arg2json.filter (z) -> return utils.isArray(z)
        # if there are array entries, then this should be alerted
        if nArray.length > 0
          utils.log 'ERROR', "Nested array found on line #{r.line}"
          return 'failed'

        return 'ok'
      catch e
        utils.log 'ERROR', "Invalid array on line #{r.line}"
        return 'failed'
  return 'ok'

# Using the exec form is recommended for certain instructions
# Reports: WARN
exports.recommended_exec_form = (rules) ->
  for i in [ 'CMD', 'ENTRYPOINT' ]
    rule = this.getAll(i, rules)
    for r in rule
      nr = r.arguments.join(' ').split(/,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)/, -1)
      lbracket = nr[0].match(/\[/g)
      rbracket = nr[nr.length-1].match(/\]/g)

      if !lbracket? || !rbracket?
        utils.log exports.pedantic_severity, "Recommended exec/array form not used on line #{r.line}"
        return exports.pedantic_ret
  return 'ok'

# Although ADD and COPY are functionally similar, generally speaking, COPY is preferred.
# The only/best use for ADD is to add-and-extract archives to an image.
# Reports: WARN
exports.add = (rules) ->
  add = this.getAll('ADD', rules)
  if add.length > 0
    lines = []
    for rule in add
      # If the source file is a recognized format (tar, gz, bz, xz), it's allowed
      # usage of ADD. Because image size matters, using ADD to fetch packages from
      # remote URLs is strongly discouraged; you should use curl or wget instead.
      # That way you can delete the files you no longer need after they've been
      # extracted and you won't have to add another layer in your image.
      lines.push rule.line unless rule.arguments[0].match(/\.(tar|gz|bz2|xz)/)

    if lines.length > 0
      utils.log exports.pedantic_severity, "ADD instruction used instead of COPY on line #{lines.join ', '}"
      return exports.pedantic_ret
  return 'ok'

# There can only be one CMD/ENTRYPOINT instruction in a Dockerfile.
# If you list more than one CMD then only the last CMD will take effect.
# Reports: ERROR
exports.multiple_entries = (rules) ->
  for e in [ 'CMD', 'ENTRYPOINT' ]
    rule = this.getAll(e, rules)
    if rule.length > 1
      utils.log 'ERROR', "Multiple #{e} instructions found, only line #{rule[rule.length-1].line} will take effect"
      return 'failed'
  return 'ok'

# You should avoid installing or using sudo since it has unpredictable TTY and
# signal-forwarding behavior that can cause more more problems than it solves
# Reports: WARN
exports.sudo = (rules) ->
  run = this.getAll('RUN', rules)
  for rule in run
    for argument in rule.arguments
      if argument.match /(^|.*;)\s*(\/?.*\/)?sudo(\s|$)/
        utils.log exports.pedantic_severity, "sudo(8) usage found on line #{rule.line} which is discouraged"
        return exports.pedantic_ret
  return 'ok'

# Check ENV syntax and save the variables for further evaluation if needed.
# Reports: ERROR
exports.env = (rules) ->
  environs = this.getAll('ENV', rules)
  for rule in environs
    unless exports.mergeVariables(exports.env, rule) is 'ok'
      utils.log 'ERROR', "ENV invalid format #{rule.arguments} on line #{rule.line}"
      return 'failed'
  return 'ok'

# Check ARG syntax and save the variables for further evaluation if needed.
# Save pre-defined ARG variables
# Reports: ERROR
exports.arg = (rules) ->
  for pre in ['HTTP_PROXY', 'http_proxy', 'HTTPS_PROXY', 'http_proxy', 'FTP_PROXY', 'ftp_proxy', 'NO_PROXY', 'no_proxy']
    exports.arg[pre] = 'true'

  args = this.getAll('ARG', rules)
  for rule in args
    unless exports.mergeVariables(exports.arg, rule) is 'ok'
      utils.log 'ERROR', "ARG invalid format #{rule.arguments} on line #{rule.line}"
      return 'failed'
  return 'ok'

# For clarity and reliability, you should always use absolute paths for your WORKDIR.
# Reports: ERROR
exports.absolute_workdir = (rules) ->
  vars = this.getAllVariables(rules)
  workdir = this.getAll('WORKDIR', rules)
  for rule in workdir
    while match = exports.varPattern.exec(rule.arguments[0])
      m = match[1] || match[2]
      if exports.arg[m]
        unless exports.env[m]
          utils.log exports.pedantic_severity, "WORKDIR path #{rule.arguments} contains an ARG variable. WORKDIR should resolve to an absolute path at build time"
          return exports.pedantic_ret

    rule.arguments[0] = exports.variablesReplace(vars, rule.arguments[0])

    if (typeof path.isAbsolute != "undefined")
      absolute = path.isAbsolute(rule.arguments[0])
    else
      absolute = rule.arguments[0].charAt(0) == '/';

    unless absolute
      utils.log 'ERROR', "WORKDIR path #{rule.arguments} must be absolute on line #{rule.line}"
      return 'failed'
  return 'ok'

# Be careful when putting ADD or COPY in ONBUILD.
# Reports: WARN
exports.onbuild_copyadd = (rules) ->
  onbuild = this.getAll('ONBUILD', rules)
  for rule in onbuild
    for argument in rule.arguments
      if argument.match /ADD|COPY/
        utils.log exports.pedantic_severity, "It is advised not to use ADD or COPY for ONBUILD on line #{rule.line}"
        return exports.pedantic_ret
  return 'ok'

# Chaining ONBUILD instructions using ONBUILD ONBUILD isn't allowed.
# The ONBUILD instruction may not trigger FROM or MAINTAINER instructions.
# Reports: ERROR
exports.onbuild_disallowed = (rules) ->
  onbuild = this.getAll('ONBUILD', rules)
  for rule in onbuild
    for argument in rule.arguments
      chained_instruction = argument.split(' ')[0]
      if chained_instruction.match(/ONBUILD|FROM|MAINTAINER/)
        utils.log 'ERROR', "ONBUILD may not be chained with #{chained_instruction} on line #{rule.line}"
        return 'failed'
  return 'ok'

# LABEL instructions are a key-value pair, of which the value may be ommitted
# iff there is no equal sign.
# Reports: ERROR
# Docker: 1.6
exports.label_no_empty_value = (rules) ->
  label = this.getAll('LABEL', rules)
  for rule in label
    for argument in rule.arguments
      for pair in argument.split(' ')
        if pair.slice(-1) == '='
          utils.log 'ERROR', "LABEL requires value for line #{rule.line}"
          return 'failed'
  return 'ok'

# Variables used within allowed instructions must be defined in ENV or ARG
# Reports: ERROR
exports.variable_use = (rules) ->
  vars = this.getAllVariables(rules)
  for i in [ 'ADD', 'COPY', 'ENV', 'EXPOSE', 'FROM', 'LABEL', 'ONBUILD', 'RUN', 'STOPSIGNAL', 'USER', 'VOLUME', 'WORKDIR' ]
    instruction = this.getAll(i, rules)
    for rule in instruction
      for argument in rule.arguments
        unless exports.variablesDefined(vars, argument) is 'ok'
          utils.log 'ERROR', "#{rule.instruction} contains undefined ARG or ENV variable on line #{rule.line}"
          return 'failed'
  return 'ok'

# No trailing spaces
exports.no_trailing_spaces = (rules) ->
  for rule in rules
    if rule.raw.endsWith ' '
      utils.log 'ERROR', 'Lines cannot have trailing spaces'
      return 'failed'
  return 'ok'
