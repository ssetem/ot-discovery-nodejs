/* jshint ignore:start */
'use strict';

//mocha required options*****************
require('babel/register');
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
var gulpif = require('gulp-if');

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

function filterPaths(filetype, args) {
  var paths = [];
  _.each(arguments, function(arg) {
    _.each(arg, function(path) {
      if (path.indexOf(filetype) > 0)
        paths.push(path);
    });
  });
  return paths;
}

function test(gulp, path, opts) {
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

var coverageTest = function(cb, paths, mochaOpts, skipCoverage) {
  //checking to see if we have any coffeescript files, then we gotta load up gci instead of babel
  if (JSON.stringify(paths).indexOf('.coffee') > -1) {
    istanbul = require('gulp-coffee-istanbul');
  } else {
    require('babel/register');
    istanbul = require('gulp-istanbul');
  }

  var testsPaths = createFilteredPaths(paths.tests, paths.noCoverageTests);

  gulp.src(paths.scripts)
    .pipe(istanbul({
      instrumenter: isparta.Instrumenter,
      includeUntested: true
    })) // Force `require` to return covered files
    .pipe(istanbul.hookRequire()) // Force `require` to return covered files
    .on('finish', function() {
      var doCoverage = !skipCoverage;
      test(gulp, testsPaths, mochaOpts)
        .pipe(gulpif(doCoverage,
          istanbul.writeReports({
            dir: paths.coverage,
            reportOpts: {
              dir: paths.coverage
            },
            reporters: ['text', 'text-summary', 'json', 'html', 'teamcity']
          })
        ))
        .pipe(gulpif(doCoverage,
          coverageEnforcer({
            thresholds: defaultCoverageThresholds,
            coverageDirectory: paths.coverage,
            rootDirectory: ''
          })
        ))
        .on('finish', cb)
        .once('error', function() {
          process.exit(1);
        })
        .once('end', function() {
          process.exit();
        });
    });
}

gulp.task('test-all-coverage', function(cb) {
  coverageTest(cb, defaultPaths);
});

gulp.task('coffeelint', function() {
  var src = filterPaths(".coffee", defaultPaths.scripts, defaultPaths.tests);
  gulp.src(src)
    .pipe(coffeelint({
      "max_line_length": {
        "level": "ignore"
      }
    }))
    .pipe(coffeelint.reporter())
    .pipe(coffeelint.reporter('fail'))
});

gulp.task('jslint', function() {
  var src = filterPaths(".js", defaultPaths.scripts, defaultPaths.tests);
  return gulp.src(src)
    .pipe(jshint())
    .pipe(jshint.reporter())
    .pipe(jshint.reporter('fail'));
});

gulp.task('default', ['jslint', 'coffeelint', 'test-all-coverage']);

gulp.task('lint', ['jslint', 'coffeelint']);

gulp.task('test', function(cb) {
  coverageTest(cb, defaultPaths, null, true);
});

/* jshint ignore:end */