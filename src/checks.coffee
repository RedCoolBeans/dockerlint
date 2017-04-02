os    = require 'os'
path  = require 'path'
utils = require "#{__dirname}/utils"

exports.all = [
  'from_first',
  'no_empty_tag',
  'no_empty_digest',
  'json_array_brackets',
  'json_array_even_quotes',
  'json_array_format',
  'recommended_exec_form',
  'add',
  'multiple_entries',
  'sudo',
  'absolute_workdir',
  'onbuild_copyadd',
  'onbuild_disallowed',
  'label_no_empty_value'
]

Array::filter = (func) -> x for x in @ when func(x)

# Returns all rules for `instruction`
exports.getAll = (instruction, rules) ->
  rules.filter (r) -> r.instruction is instruction

# Returns all rules except those for `instruction`.
exports.getAllExcept = (instruction, rules) ->
  rules.filter (r) -> r.instruction isnt instruction

# FROM must be the first non-comment instruction in the Dockerfile
# Reports: ERROR
exports.from_first = (rules) ->
  non_comments = this.getAllExcept('comment', rules)
  first = non_comments[0]

  if first.instruction isnt 'FROM'
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
        if argument.match /\[.*\]/
          # Break the literal array into it's logical components
          for arg in argument.split ','
            if not arg.trim().match /^\[?\".*\"\]?$/
              utils.log 'ERROR', errmsg
              return 'failed'
        else
          if argument.match /\[.*'.*\]/
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

# Using the exec form is recommended for certain instructions
# Reports: WARN
exports.recommended_exec_form = (rules) ->
  for i in [ 'CMD', 'ENTRYPOINT' ]
    rule = this.getAll(i, rules)
    for r in rule
      lbracket = r.arguments[0].match(/\[/g)
      rbracket = r.arguments[0].match(/\]/g)

      if !lbracket? || !rbracket?
        utils.log 'WARN', "Recommended exec/array form not used on line #{r.line}"
        return 'failed'
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
      # usage of ADD.
      lines.push rule.line unless rule.arguments[0].match(/\.(tar|gz|bz2|xz)/)

    if lines.length > 0
      utils.log 'WARN', "ADD instruction used instead of COPY on line #{lines.join ', '}"
      return 'failed'
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
        utils.log 'WARN', "sudo(8) usage found on line #{rule.line} which is discouraged"
        return 'failed'
  return 'ok'

# For clarity and reliability, you should always use absolute paths for your WORKDIR.
# Reports: ERROR
exports.absolute_workdir = (rules) ->
  workdir = this.getAll('WORKDIR', rules)
  for rule in workdir
    # On *NIX we can assume that normalize() and resolve() return the same value
    # for absolute paths. This allows us to keep working on Node < 0.12.0 where
    # path.isAbsolute() is not available.
    # For the Windows case the assumption doesn't hold and therefore we require
    # the use of path.isAbsolute().
    if os.platform() is 'win32'
      absolute = path.isAbsolute(rule.arguments[0])
    else
      absolute = path.normalize(rule.arguments[0]) is path.resolve(rule.arguments[0])

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
        utils.log 'WARN', "It is advised not to use ADD or COPY for ONBUILD on line #{rule.line}"
        return 'failed'
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
