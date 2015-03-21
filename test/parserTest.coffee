p    = require '../src/parser.coffee'
chai = require 'chai'
chai.should()

describe "getInstruction", ->
  it "should return the first word from a string", ->
    p.getInstruction("FROM cargos:latest").should.equal "FROM"

  it "should return the first word from a string with hard tabs", ->
    p.getInstruction("MAINTAINER	cargos:latest").should.equal "MAINTAINER"

  it "should return 'comment' for lines starting with '#'", ->
    p.getInstruction('# Apology accepted, Captain Needa').should.equal 'comment'

describe "getArguments", ->
  it "should return an Array", ->
    p.getArguments('USER darth').should.be.instanceOf(Array)

  it "should return everything but the first word from a string", ->
    p.getArguments('FROM cargos:latest').should.be.deep.equal ['cargos:latest']

  it "should handle comments", ->
    p.getArguments('# Invalidate layer').should.be.deep.equal ['Invalidate layer']

  it "should remove trailing backslashes", ->
    p.getArguments('RUN yum -y update \\').should.be.deep.equal ['yum -y update']

  it "should remove trailing backslashes followed by whitespace", ->
    p.getArguments('RUN yum -y update \\       ').should.be.deep.equal ['yum -y update']

  it "should leave backslashes elsewhere", ->
    p.getArguments('RUN yum -y update && \\ yum -y install tmux').should.be.deep.equal ['yum -y update && \\ yum -y install tmux']

describe "parser", ->
  it "should handle empty files", ->
    p.parser('test/dockerfiles/empty').should.be.deep.equal []

  it "should handle comment-only files", ->
    p.parser('test/dockerfiles/comment_only').should.be.deep.equal [{line: 1, instruction: 'comment', arguments: ['MIT licensed']}]

  it "should return nothing when handling a non-existent file", ->
    p.parser('test/dockerfiles/nonexistent-file').should.be.deep.equal []

  it "should count the lines correctly", ->
    p.parser('test/dockerfiles/line_count')[3].line.should.be.deep.equal 8

  it "should handle line continuations", ->
    output = [
      { line: 1, instruction: 'FROM', arguments: [ 'cargos:latest' ] },
      { line: 3, instruction: 'RUN',  arguments: [ 'yum update &&', 'yum install mg &&', 'yum upgrade' ] },
      { line: 7, instruction: 'RUN',  arguments: [ 'yum -y update && \\\\ yum -y install tmux' ] }
    ]
    p.parser('test/dockerfiles/line_continuations').should.be.deep.equal output
