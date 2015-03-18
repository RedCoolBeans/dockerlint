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

  it "should leave backslashes elsewhere", ->
    cmd = 'RUN yum -y update && \\ yum -y install tmux'
    parser.getArguments('RUN yum -y update && \\ yum -y install tmux').should.equal ['yum -y update && \\ yum -y install tmux']

describe "parser", ->
  it "should handle empty files"
  it "should count the lines"
  it "should handle a non-existent file"
  it "should handle line continuations"
