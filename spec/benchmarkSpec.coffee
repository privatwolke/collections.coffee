collections = require "../src/collections"
now = require "performance-now"

xdescribe "Performance Benchmark", ->

	db = null
	c = null

	TEST_RECORDS = []

	# test with one millon records
	for i in [0 .. 1000000]
		TEST_RECORDS.push(
			name: Math.random().toString(36).substr(2, 100)
			age: Math.random()
			active: true
		)


	beforeEach ->
		start = now()
		db = new collections.Database()
		c = db.collection("test")
		end = now()

		console.log("creating database: #{(end - start).toFixed(2)}ms")


	afterEach ->
		db.drop("test")


	it "should perform well", ->
		start = now()
		c.add(TEST_RECORDS)
		end = now()

		console.log("Adding: #{(end - start).toFixed(2)}ms")

		start = now()
		c.index("age")
		end = now()

		console.log("Indexing: #{(end - start).toFixed(2)}ms")

		start = now()
		result = c.all()
		end = now()

		console.log("all(): #{(end - start).toFixed(2)}ms")

		start = now()
		result.sort(collections.fn.sortAscending("name"))
		end = now()

		console.log("sort(): #{(end - start).toFixed(2)}ms")

		start = now()
		c.query("age", (k) -> k.age > 0.2)
		end = now()

		console.log("query(): #{(end - start).toFixed(2)}ms")

		start = now()
		c.get(222)
		end = now()

		console.log("get(): #{(end - start).toFixed(2)}ms")
