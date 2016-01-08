c    = require '../src/checks.coffee'
chai = require 'chai'
chai.should()

rules = [
  { line: 1, instruction: 'comment', arguments: ['MIT licensed'] },
  { line: 2, instruction: 'FROM', arguments: [ 'cargos:latest' ] },
  { line: 3, instruction: 'RUN',  arguments: [ 'yum update &&', 'yum install mg &&', 'yum upgrade' ] },
]

describe "getAll", ->
  it "should return an Array", ->
    c.getAll('FROM', rules).should.be.instanceOf(Array)

  it "should return all rules for a given instruction", ->
    c.getAll('FROM', rules).should.be.deep.equal [rules[1]]

  it "should return all comments", ->
    c.getAll('comment', rules).should.be.deep.equal [rules[0]]

  it "should return an empty Array if the instruction is not found", ->
    c.getAll('JETPACK', rules).should.be.deep.equal []

describe "getAllExcept", ->
  it "should return an Array", ->
    c.getAllExcept('FROM', rules).should.be.instanceOf(Array)

  it "should return all rules except those for the given instruction", ->
    c.getAllExcept('comment', rules).should.be.deep.equal [rules[1], rules[2]]

  it "should return an the same Array if the instruction is not found", ->
    c.getAllExcept('JETPACK', rules).should.be.deep.equal rules

describe "from_first", ->
  it "should fail if FROM is not the first instruction", ->
    r = [
      { line: 1, instruction: 'RUN', arguments: ['yum -y update'] },
      { line: 2, instruction: 'FROM', arguments: [ 'cargos:latest' ] },
    ]
    c.from_first(r).should.be.equal 'failed'

  it "should not fail if FROM is the first instruction, but but preceeded by comments", ->
    c.from_first(rules).should.be.equal 'ok'

  it "should fail if no FROM is found", ->
    r = [
      { line: 1, instruction: 'EXPOSE', arguments: ['80'] },
      { line: 2, instruction: 'RUN', arguments: [ 'sshd -D' ] },
    ]
    c.from_first(r).should.be.equal 'failed'

describe "no_empty_tag", ->
  it "should fail if no tag is set when one is expected", ->
    c.no_empty_tag([ {line: 1, instruction: 'FROM', arguments: ['cargos:']} ]).should.be.equal 'failed'

describe "no_empty_digest", ->
  it "should fail if no digest is set when one is expected", ->
    c.no_empty_digest([ {line: 1, instruction: 'FROM', arguments: ['cargos@']} ]).should.be.equal 'failed'

describe "json_array_format", ->
  for cmd in [ 'CMD', 'ENTRYPOINT', 'RUN', 'VOLUME' ]
    it "should not fail on single quotes in #{cmd} non-exec form", ->
      c.json_array_format([ {line: 1, instruction: cmd, arguments: ['\'/tmp\'']} ]).should.be.equal 'ok'

    it "should fail when single quotes are used in #{cmd} exec form", ->
      c.json_array_format([ {line: 1, instruction: cmd, arguments: ['[\'/root\']']} ]).should.be.equal 'failed'

    it "should not fail when double quotes are used in #{cmd} exec form", ->
      c.json_array_format([ {line: 1, instruction: cmd, arguments: ['["/root"]']} ]).should.be.equal 'ok'

describe "json_array_even_quotes", ->
  for cmd in [ 'CMD', 'ENTRYPOINT', 'RUN', 'VOLUME' ]
    r = [ {line: 1, instruction: cmd, arguments: ['"""']} ]
    it "should fail when there are an unbalanced number of quotes in #{cmd} exec form", ->
      c.json_array_even_quotes(r).should.be.equal 'failed'

describe "json_array_brackets", ->
  for cmd in [ 'CMD', 'ENTRYPOINT', 'RUN', 'VOLUME' ]
    it "should not act on non-exec form arguments for #{cmd}", ->
      c.json_array_brackets([ {line: 1, instruction: cmd, arguments: ['"foo"'] }]).should.be.equal 'ok'
    for test in [
      {desc: "are multiple closing brackets", test: '[["foo"]'},
      {desc: "are multiple opening brackets", test: '["bar"]]'},
      {desc: "is no opening bracket", test: '"baz"]'},
      {desc: "is no closing bracket", test: '["quux"'}]
      it "should fail if #{test.desc} for #{cmd}", ->
        c.json_array_brackets([ {line: 1, instruction: cmd, arguments: [test.test] }]).should.be.equal 'failed'

describe "recommended_exec_form", ->
  for cmd in [ 'CMD', 'ENTRYPOINT' ]
    r = [ {line: 1, instruction: cmd, arguments: ["/entrypoint.sh"]} ]
    it "should warn when not using exec form for #{cmd}", ->
      c.recommended_exec_form(r).should.be.equal 'failed'

describe "add", ->
  it "should warn when ADD it used", ->
    c.add([ {line: 1, instruction: 'ADD', arguments: ['/config.json /']} ]).should.be.equal 'failed'

  for archive in [ 'tar', 'tar.gz', 'gz', 'bz2', 'xz', 'tar.xz' ]
    it "should not fail when ADD is used with an #{archive} archive", ->
      c.add([ {line: 1, instruction: 'ADD', arguments: ["/file.#{archive}} /"]} ]).should.be.equal 'ok'

describe "multiple_entries", ->
  for cmd in [ 'CMD', 'ENTRYPOINT' ]
    it "should fail when multiple #{cmd} are set", ->
      r = [
        { line: 1, instruction: cmd, arguments: ['/sbin/sshd -D'] },
        { line: 2, instruction: cmd, arguments: ['/sbin/sshd -D'] },
      ]
      c.multiple_entries(r).should.be.equal 'failed'

describe "sudo", ->
  it "should warn when sudo is used", ->
    c.sudo([ {line: 1, instruction: 'RUN', arguments: ['sudo rm -rf /']} ]).should.be.equal 'failed'

describe "absolute_workdir", ->
  it "should fail when WORKDIR uses a relative path", ->
    c.absolute_workdir([ {line: 1, instruction: 'WORKDIR', arguments: ['../']} ]).should.be.equal 'failed'

  it "should not fail when WORKDIR uses an absolute path", ->
    c.absolute_workdir([ {line: 1, instruction: 'WORKDIR', arguments: ['/']} ]).should.be.equal 'ok'

describe "onbuild_copyadd", ->
  for cmd in [ 'ADD', 'COPY' ]
    it "should fail when #{cmd} is used with ONBUILD", ->
      c.onbuild_copyadd([ {line: 1, instruction: 'ONBUILD', arguments: ["#{cmd} /file /"]} ]).should.be.equal 'failed'

describe "onbuild_disallowed", ->
  for cmd in [ 'FROM', 'ONBUILD', 'MAINTAINER' ]
    it "should fail when #{cmd} is used with ONBUILD", ->
      c.onbuild_disallowed([ {line: 1, instruction: 'ONBUILD', arguments: [cmd]} ]).should.be.equal 'failed'

describe "label_no_empty_value", ->
  it "should fail when LABEL expects a value and it's not set", ->
    c.label_no_empty_value([ {line: 1, instruction: 'LABEL', arguments: ['key=']} ]).should.be.equal 'failed'

  it "should pass when LABEL is a key and no value is expected", ->
    c.label_no_empty_value([ {line: 1, instruction: 'LABEL', arguments: ['key']} ]).should.be.equal 'ok'

  it "should pass when LABEL is a key=value", ->
    c.label_no_empty_value([ {line: 1, instruction: 'LABEL', arguments: ['key=value']} ]).should.be.equal 'ok'
