expect = require("chai").expect
sinon = require "sinon"

replaceMethod = (obj, method, fn) ->
  expect(obj).to.respondTo method
  fn ?= sinon.spy()
  obj[method] = fn

module.exports =
  replaceMethod: replaceMethod
