checks = require '../src/checks.coffee'
chai   = require 'chai'
chai.should()

rules = [
  { line: 1, instruction: 'comment', arguments: ['MIT licensed'] },
  { line: 2, instruction: 'FROM', arguments: [ 'cargos:latest' ] },
  { line: 3, instruction: 'RUN',  arguments: [ 'yum update &&', 'yum install mg &&', 'yum upgrade' ] },
]

describe "getAll", ->
  it "should return an Array", ->
    checks.getAll('FROM', rules).should.be.instanceOf(Array)

  it "should return all rules for a given instruction", ->
    checks.getAll('FROM', rules).should.be.deep.equal [rules[1]]

  it "should return all comments", ->
    checks.getAll('comment', rules).should.be.deep.equal [rules[0]]

  it "should return an empty Array if the instruction is not found", ->
    checks.getAll('JETPACK', rules).should.be.deep.equal []

describe "getAllExcept", ->
  it "should return an Array", ->
    checks.getAllExcept('FROM', rules).should.be.instanceOf(Array)

  it "should return all rules except those for the given instruction", ->
    checks.getAllExcept('comment', rules).should.be.deep.equal [rules[1], rules[2]]

  it "should return an the same Array if the instruction is not found", ->
    checks.getAllExcept('JETPACK', rules).should.be.deep.equal rules

describe "from_first", ->
  it "should fail if FROM is not the first instruction", ->
    r = [
      { line: 1, instruction: 'RUN', arguments: ['yum -y update'] },
      { line: 2, instruction: 'FROM', arguments: [ 'cargos:latest' ] },
    ]
    checks.from_first(r).should.be.equal 'failed'

  it "should not fail if FROM is the first instruction, but but preceeded by comments", ->
    checks.from_first(rules).should.be.equal 'ok'

  it "should fail if no FROM is found", ->
    r = [
      { line: 1, instruction: 'EXPOSE', arguments: ['80'] },
      { line: 2, instruction: 'RUN', arguments: [ 'sshd -D' ] },
    ]
    checks.from_first(r).should.be.equal 'failed'

describe "no_empty_tag", ->
  it "should fail if no tag is set when one is expected", ->
    checks.no_empty_tag([ {line: 1, instruction: 'FROM', arguments: ['cargos:']} ]).should.be.equal 'failed'

describe "json_array_format", ->
  for cmd in [ 'CMD', 'ENTRYPOINT', 'RUN', 'VOLUME' ]
    it "should not fail on single quotes in #{cmd} non-exec form", ->
      checks.json_array_format([ {line: 1, instruction: cmd, arguments: ['\'/tmp\'']} ]).should.be.equal 'ok'

    it "should fail when single quotes are used in #{cmd} exec form", ->
      checks.json_array_format([ {line: 1, instruction: cmd, arguments: ['[\'/root\']']} ]).should.be.equal 'failed'

    it "should not fail when double quotes are used in #{cmd} exec form", ->
      checks.json_array_format([ {line: 1, instruction: cmd, arguments: ['["/root"]']} ]).should.be.equal 'ok'

describe "json_array_even_quotes", ->
  for cmd in [ 'CMD', 'ENTRYPOINT', 'RUN', 'VOLUME' ]
    r = [ {line: 1, instruction: cmd, arguments: ['"""']} ]
    it "should fail when there are an unbalanced number of quotes in #{cmd} exec form", ->
      checks.json_array_even_quotes(r).should.be.equal 'failed'

describe "add", ->
  it "should warn when ADD it used", ->
    checks.add([ {line: 1, instruction: 'ADD', arguments: ['/config.json /']} ]).should.be.equal 'failed'

  for archive in [ 'tar', 'tar.gz', 'gz', 'bz2', 'xz', 'tar.xz' ]
    it "should not fail when ADD is used with an #{archive} archive", ->
      checks.add([ {line: 1, instruction: 'ADD', arguments: ["/file.#{archive}} /"]} ]).should.be.equal 'ok'

describe "multiple_entries", ->
  for cmd in [ 'CMD', 'ENTRYPOINT' ]
    it "should fail when multiple #{cmd} are set", ->
      r = [
        { line: 1, instruction: cmd, arguments: ['/sbin/sshd -D'] },
        { line: 2, instruction: cmd, arguments: ['/sbin/sshd -D'] },
      ]
      checks.multiple_entries(r).should.be.equal 'failed'

describe "sudo", ->
  it "should warn when sudo is used", ->
    checks.sudo([ {line: 1, instruction: 'RUN', arguments: ['sudo rm -rf /']} ]).should.be.equal 'failed'

describe "absolute_workdir", ->
  it "should fail when WORKDIR uses a relative path", ->
    checks.absolute_workdir([ {line: 1, instruction: 'WORKDIR', arguments: ['../']} ]).should.be.equal 'failed'

  it "should not fail when WORKDIR uses an absolute path", ->
    checks.absolute_workdir([ {line: 1, instruction: 'WORKDIR', arguments: ['/']} ]).should.be.equal 'ok'

describe "onbuild_copyadd", ->
  for cmd in [ 'ADD', 'COPY' ]
    it "should fail when #{cmd} is used with ONBUILD", ->
      checks.onbuild_copyadd([ {line: 1, instruction: 'ONBUILD', arguments: ["#{cmd} /file /"]} ]).should.be.equal 'failed'

describe "onbuild_disallowed", ->
  for cmd in [ 'FROM', 'ONBUILD', 'MAINTAINER' ]
    it "should fail when #{cmd} is used with ONBUILD", ->
      checks.onbuild_disallowed([ {line: 1, instruction: 'ONBUILD', arguments: [cmd]} ]).should.be.equal 'failed'