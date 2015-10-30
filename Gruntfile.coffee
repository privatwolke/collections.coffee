# This is my personal take on a Gruntfile.
# Shut up.

# This the build lifecycle:
# serve (while developing) -> build -> dist

module.exports = (grunt) ->

	configuration =
		paths:
			src:       "src"
			build:     "build"
			generated: ".generated"


	require("time-grunt") grunt

	require("jit-grunt") grunt,
		spec: "grunt-jasmine-bundle"


	grunt.initConfig

		# Make the configuration available to grunt.
		cfg: configuration


		# grunt-contrib-clean
		# Remove the build and .generated folders.
		clean: [
			"<%= cfg.paths.build %>",
			"<%= cfg.paths.generated %>"
		]


		# grunt-coffelint
		# Checks CoffeeScript files for common mistakes.
		coffeelint:
			options:
				configFile: "coffeelint.json"

			src: [
				"Gruntfile.coffee"
				"<%= cfg.paths.src %>/{,*/}*.coffee"
			]

		# grunt-contrib-coffee
		# Compile CoffeeScript to JavaScript.
		coffee:
			build:
				expand: true
				cwd: "<%= cfg.paths.src %>"
				src: ["{,*/}*.coffee"]
				dest: "<%= cfg.paths.build %>"
				ext: ".js"


	grunt.registerTask("build", [
		"clean"
		"coffeelint"
		"coffee"
	])

	grunt.registerTask("test", [
		"spec"
	])
