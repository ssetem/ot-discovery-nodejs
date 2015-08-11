/* jshint ignore:start */
'use strict';

//mocha required options*****************
require('should');
//***************************************

// Include gulp
var gulp = require('gulp');
var istanbul = require('gulp-istanbul');
// We'll use mocha here, but any test framework will work
var mocha = require('gulp-mocha');
var isparta = require('isparta');
var coverageEnforcer = require('gulp-istanbul-enforcer');
var gulpIgnore = require('gulp-ignore');
var minimist = require('minimist');
var _ = require('lodash');
var coffeelint = require('gulp-coffeelint');
var jshint = require('gulp-jshint');

var defaultPaths = {
  scripts: ['src/**/*.coffee', 'src/**/*.js'],
  tests: ['test/**/*.coffee', 'test/**/*.js'],
  noCoverageTests: [],
  coverage: 'coverage/',
  zipCoverage: 'coverage/*'
};

var defaultCoverageThresholds = {
  statements: 90,
  branches: 50,
  functions: 90,
  lines: 80
};

function createFilteredPaths(normalPaths, toFilterPaths) {
  return normalPaths.concat(toFilterPaths.map(function(item) {
    return '!' + item;
  }));
}

function filterPaths(filetype, pathObject) {
  return _.filter(
    _.flatten(pathObject.scripts, pathObject.tests),
    function(path) {
      return path.indexOf(filetype) > 0;
    }
  );
}

function test(path, opts) {
  opts = opts || {};

  var mochaOpts = minimist(process.argv.slice(2), {
    default: _.merge({
      timeout: 7000,
      require: ['./test/globals.js']
    }, opts)
  });

  return gulp.src(path, {
      read: false
    })
    .pipe(mocha(mochaOpts));
}

var coverageTest = function(cb, paths, mochaOpts) {
  istanbul = require('gulp-coffee-istanbul');

  var testsPaths = createFilteredPaths(paths.tests, paths.noCoverageTests);

  gulp.src(paths.scripts)
    .pipe(istanbul({
      instrumenter: isparta.Instrumenter,
      includeUntested: true
    })) // Force `require` to return covered files
    .pipe(istanbul.hookRequire()) // Force `require` to return covered files
    .on('finish', function() {
      test(testsPaths, mochaOpts)
        .pipe(
          istanbul.writeReports({
            dir: paths.coverage,
            reportOpts: {
              dir: paths.coverage
            },
            reporters: ['text', 'text-summary', 'json', 'html', 'teamcity']
          })
        )
        .pipe(
          coverageEnforcer({
            thresholds: defaultCoverageThresholds,
            coverageDirectory: paths.coverage,
            rootDirectory: ''
          })
        )
        .on('finish', cb)
        .on('error', cb);
    });
};

gulp.task('test', function() {
  require('coffee-script/register');
  return test(defaultPaths.tests);
});

gulp.task('test-all-coverage', function(cb) {
  coverageTest(cb, defaultPaths);
});

gulp.task('coffeelint', function() {
  var src = filterPaths('.coffee', defaultPaths);
  gulp.src(src)
    .pipe(coffeelint({
      "max_line_length": {
        "level": "ignore"
      }
    }))
    .pipe(coffeelint.reporter())
    .pipe(coffeelint.reporter('fail'));
});

gulp.task('jslint', function() {
  var src = filterPaths('.js', defaultPaths);
  return gulp.src(src)
    .pipe(jshint())
    .pipe(jshint.reporter())
    .pipe(jshint.reporter('fail'));
});

gulp.task('lint', ['jslint', 'coffeelint']);

gulp.task('default', ['lint', 'test-all-coverage']);

/* jshint ignore:end */
