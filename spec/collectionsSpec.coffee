collections = require "../src/collections"

describe "Test Suite", ->

	db = null
	c = null

	# test data
	record = "name": "Bob", "age": 26
	records = [
		record
		{"name": "Alice", "age": 24}
		{"name": "Malloy", "age": 32}
		{"name": "Julie", "age": 24}
	]

	beforeEach ->
		db = new collections.Database()
		c = db.collection("test")

	afterEach ->
		db.drop("test")

	addOneRecord = ->
		c.add(record)

	addSomeRecords = ->
		c.add(records)


	it "should create a database instance", ->
		db = new collections.Database()
		expect(db).not.toBe(null)
		expect(db.options).toBeDefined()
		expect(db.data).toBeDefined()


	it "should create a new collection", ->
		expect(db.collections().test).toBeDefined()
		expect(c.name).toBe("test")
		expect(c.database).toBe(db)
		expect(c.indices).toEqual({})


	it "should remove a collection", ->
		db.drop("test")
		expect(db.collections()).toEqual({})


	it "should add a record to a collection", ->
		id = addOneRecord()
		expect(id).toBeGreaterThan(0)
		result = c.get(id)
		expect(id).toBe(result.id)
		expect(record).toEqual(result.record)


	it "should remove a record from a collection", ->
		id = addOneRecord()
		expect(c.all().length).toBe(1)
		c.remove(id)
		expect(c.all().length).toBe(0)
		expect(c.get(id)).toBeNull()


	it "should find an added record in all records", ->
		id = addOneRecord()
		result = c.all()
		expect(result.length).toBe(1)
		expect(result.records.length).toEqual(result.length)
		expect(result.cursor).toBe(0)
		expect(result.records[0].record).toEqual(record)


	it "should add multiple records", ->
		addSomeRecords()
		expect(c.all().length).toBe(records.length)


	it "should iterate correctly", ->
		id = addOneRecord()
		result = c.all()
		nextRecord = result.next()
		expect(nextRecord.id).toBe(id)
		expect(nextRecord.record).toEqual(record)
		expect(result.cursor).toBe(1)

		# there should be no more records
		expect(result.next()).toBeUndefined()

		# the cursor should not change after we have reached the last record
		expect(result.cursor).toBe(1)


	it "should limit the result correctly", ->
		addSomeRecords()

		result = c.all()
		expect(result.length).toBe(records.length)

		limitedResult = result.limit(1)
		expect(limitedResult.length).toBe(1)


	it "should add an index", ->
		c.index("name")
		expect(c.indices.name).toBeDefined()


	it "should query an index", ->
		idx = c.index("name")
		addSomeRecords()

		result = idx.query((key) -> key.name is "Alice")
		expect(result.length).toBe(1)
		expect(result.records[0].record["name"]).toBe("Alice")
		expect(result.records[0].record["age"]).toBe(24)


	it "should index already present records", ->
		addSomeRecords()
		idx = c.index("age")
		expect(idx.query(-> true).length).toBeGreaterThan(0)


	it "should query an index with multiple keys", ->
		idx = c.index("name,age")
		addSomeRecords()

		result = idx.query((key) -> key.name is "Alice" and key.age is 24)
		expect(result.length).toBe(1)
		expect(result.records[0].record["name"]).toBe("Alice")
		expect(result.records[0].record["age"]).toBe(24)


	it "should filter a result set", ->
		addSomeRecords()

		result = c.all().filter((row) -> row.record["age"] > 25)
		expect(result.length).toBe(2)
		for row in result.list()
			expect(row.record["age"]).toBeGreaterThan(25)


	it "should sort a result set ascending", ->
		addSomeRecords()

		result = c.all().sort(collections.fn.sortAscending("age"))
		lastAge = 0
		for row in result.list()
			expect(row.record["age"] >= lastAge).toBeTruthy()
			lastAge = row.record["age"]


	it "should sort a result set descending", ->
		addSomeRecords()

		result = c.all().sort(collections.fn.sortDescending("age"))
		lastAge = 9999
		for row in result.list()
			expect(row.record["age"] <= lastAge).toBeTruthy()
			lastAge = row.record["age"]


	it "should filter for a match using the provided 'is' function", ->
		addSomeRecords()
		result = c.all().filter(collections.fn.is("name", "Bob"))
		expect(result.length).toBe(1)
		expect(result.records[0].record["name"]).toBe("Bob")


	it "should update a record correctly", ->
		id = addOneRecord()
		record = c.all().records[0]
		record.record["name"] = "Gemma"
		c.update(record)

		updatedRecord = c.all().records[0]
		expect(updatedRecord.id).toBe(id)
		expect(updatedRecord.record["name"]).toBe("Gemma")
		expect(updatedRecord.record["age"]).toBe(record.record["age"])


	it "should fail to update a record without id", ->
		test = -> c.update(record: name: "Gemma", age: 24)
		expect(test).toThrow("Can't update a record without an 'id' property.")


	it "should fail to update a non existant record", ->
		test = -> c.update(id: 1, record: name: "Gemma", age: 24)
		expect(test).toThrow("Can't update this record. It's not in the database.")


	it "should not complain about removing non existant records", ->
		expect(c.all().length).toBe(0)
		expect(-> c.remove(1)).not.toThrow()


	it "should pass an object to filter function when querying an index", ->
		addSomeRecords()
		idx = c.index("name")
		fns = fn: (key) -> true
		spyOn(fns, 'fn')
		idx.query(fns.fn)
		expect(fns.fn).toHaveBeenCalledWith(name: "Bob")


	it "should not change a record in the database without explicit update", ->
		id = addOneRecord()
		savedRecord = c.get(id)
		name = savedRecord.record["name"]
		savedRecord.record["name"] = "George"
		expect(c.get(id).record.name).not.toBe("George")
