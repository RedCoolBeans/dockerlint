parser = require '../src/parser.coffee'
chai   = require 'chai'
chai.should()

describe "getInstruction", ->
  it "should return the first word from a string", ->
    parser.getInstruction("FROM cargos:latest").should.equal "FROM"

  it "should return 'comment' for lines starting with '#'", ->
    parser.getInstruction('# Apology accepted, Captain Needa').should.equal 'comment'

describe "getArguments", ->
  it "should return an Array", ->
    parser.getArguments('USER darth').should.be.instanceOf(Array)

  it "should return everything but the first word from a string", ->
    parser.getArguments('FROM cargos:latest').should.be.deep.equal ['cargos:latest']

  it "should handle comments", ->
    parser.getArguments('# Invalidate layer').should.be.deep.equal ['Invalidate layer']

  it "should remove trailing backslashes", ->
    parser.getArguments('RUN yum -y update \\').should.be.deep.equal ['yum -y update']

  it "should remove trailing backslashes followed by whitespace", ->
    parser.getArguments('RUN yum -y update \\       ').should.be.deep.equal ['yum -y update']

  it "should leave backslashes elsewhere", ->
    parser.getArguments('RUN yum -y update && \\ yum -y install tmux').should.be.deep.equal ['yum -y update && \\ yum -y install tmux']

describe "parser", ->
  it "should handle empty files", ->
    parser.parser('test/dockerfiles/empty').should.be.deep.equal []

  it "should handle comment-only files", ->
    parser.parser('test/dockerfiles/comment_only').should.be.deep.equal [{line: 1, instruction: 'comment', arguments: ['MIT licensed']}]

  it "should return nothing when handling a non-existent file", ->
    parser.parser('test/dockerfiles/nonexistent-file').should.be.deep.equal []

  it "should count the lines correctly", ->
    parser.parser('test/dockerfiles/line_count')[3].line.should.be.deep.equal 8

  it "should handle line continuations", ->
    output = [
      { line: 1, instruction: 'FROM', arguments: [ 'cargos:latest' ] },
      { line: 3, instruction: 'RUN',  arguments: [ 'yum update &&', 'yum install mg &&', 'yum upgrade' ] },
      { line: 7, instruction: 'RUN',  arguments: [ 'yum -y update && \\\\ yum -y install tmux' ] }
    ]
    parser.parser('test/dockerfiles/line_continuations').should.be.deep.equal output
