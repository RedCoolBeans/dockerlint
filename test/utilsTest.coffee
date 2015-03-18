utils = require '../src/utils.coffee'

describe "beginsWith", ->
  it "should return true if the argument matches the first character", ->
    'Greedo'.beginsWith('G').should.equal true

  it "should return false if the argument does not match the first character", ->
    'Jango'.beginsWith('G').should.equal false

describe "endsWith", ->
  it "should return true if the argument matches the last character", ->
    'Zam'.endsWith('m').should.equal true

  it "should return false if the argument does not match the last character", ->
    'Aurra'.endsWith('A').should.equal false

describe "notEmpty", ->
  it "should return false if string is empty", ->
    utils.notEmpty('').should.equal false

  it "should return true if string is not empty", ->
    utils.notEmpty('Jabba').should.equal true
