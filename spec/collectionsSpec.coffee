collections = require "../src/collections"

describe "Test Suite", ->

	# test data
	record = "name": "Bob", "age": 26
	records = [
		record
		{"name": "Alice", "age": 24}
		{"name": "Malloy", "age": 32}
		{"name": "Julie", "age": 24}
	]

	afterEach ->
		delete @id
		delete @ids
		delete @index
		delete @database
		delete @collection

	addOneRecord = (collection) ->
		collection.add(record)

	addSomeRecords = (collection) ->
		collection.add(records)


	it "should create a database instance", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				expect(@database).not.toBe(null)
				expect(@database.options).toBeDefined()
				expect(@database.data).toBeDefined()
				done()


	it "should create a new collection", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (collection) =>
				expect(collection.name).toBe("test")
				expect(collection.database).toBe(@database)
				expect(collection.indices).toEqual({})

			.then =>
				@database.drop("test")

			.then -> done()


	it "should remove a collection", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then =>
				@database.collections()

			.then (collections) =>
				expect(collections).not.toEqual({})

			.then =>
				@database.drop("test")

			.then =>
				@database.collections()

			.then (collections) =>
				expect(collections).toEqual({})
				done()


	it "should add a record to a collection", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addOneRecord(@collection)

			.then (@id) =>
				expect(id).toBeGreaterThan(0)
				@collection.get(@id)

			.then (result) =>
				expect(result.id).toBe(@id)
				expect(record).toEqual(result.record)
				@database.drop("test")

			.then -> done()


	it "should remove a record from a collection", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addOneRecord(@collection)

			.then (@id) =>
				@collection.all()

			.then (result) =>
				expect(result.length).toBe(1)
				@collection.remove(@id)

			.then =>
				@collection.all()

			.then (result) =>
				expect(result.length).toBe(0)
				@collection.get(@id)

			.then (result) =>
				expect(result).toBeNull()
				@database.drop("test")

			.then -> done()


	it "should find an added record in all records", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addOneRecord(@collection)

			.then (@id) =>
				@collection.all()

			.then (result) =>
				expect(result.length).toBe(1)
				expect(result.records.length).toEqual(result.length)
				expect(result.cursor).toBe(0)
				expect(result.records[0].record).toEqual(record)
				@database.drop("test")

			.then -> done()


	it "should add multiple records", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (@ids) =>
				@collection.all()

			.then (result) =>
				expect(result.length).toBe(records.length)
				@database.drop("test")

			.then -> done()


	it "should iterate correctly", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addOneRecord(@collection)

			.then (@id) =>
				@collection.all()

			.then (result) =>
				expect(result.cursor).toBe(0)
				nextRecord = result.next()
				expect(nextRecord.id).toBe(@id)
				expect(nextRecord.record).toEqual(record)
				expect(result.cursor).toBe(1)

				# there should be no more results
				expect(result.next()).toBeUndefined()

				# the cursor should not change after we have reached the last record
				expect(result.cursor).toBe(1)

				@database.drop("test")

			.then -> done()


	it "should limit the result correctly", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (@ids) =>
				@collection.all()

			.then (result) =>
				expect(result.length).toBe(records.length)
				limitedResult = result.limit(1)
				expect(limitedResult.length).toBe(1)

				@database.drop("test")

			.then -> done()


	it "should add an index", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				@collection.index("name")

			.then (index) =>
				expect(index).toBeDefined()
				@database.drop("test")

			.then -> done()


	it "should query an index", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				@collection.index("name")

			.then (@index) =>
				addSomeRecords(@collection)

			.then (ids) =>
				@index.query((key) -> key.name is "Alice")

			.then (result) =>
				expect(result.length).toBe(1)
				expect(result.records[0].record["name"]).toBe("Alice")
				expect(result.records[0].record["age"]).toBe(24)

				@database.drop("test")

			.then -> done()


	it "should index already present records", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (ids) =>
				@collection.index("age")

			.then (index) ->
				index.query(-> true)

			.then (result) =>
				expect(result.length).toBeGreaterThan(0)

				@database.drop("test")

			.then -> done()


	it "should query an index with multiple keys", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (ids) =>
				@collection.index("name,age")

			.then (index) ->
				index.query((key) -> key.name is "Alice" and key.age is 24)

			.then (result) =>
				expect(result.length).toBe(1)
				expect(result.records[0].record["name"]).toBe("Alice")
				expect(result.records[0].record["age"]).toBe(24)

				@database.drop("test")

			.then -> done()


	it "should filter a result set", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (ids) =>
				@collection.all()

			.then (result) =>
				result = result.filter((row) -> row.record["age"] > 25)
				expect(result.length).toBe(2)
				for row in result.list()
					expect(row.record["age"]).toBeGreaterThan(25)

				@database.drop("test")

			.then -> done()


	it "should sort a result set ascending", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (ids) =>
				@collection.all()

			.then (result) =>
				result = result.sort(collections.fn.sortAscending("age"))
				lastAge = 0
				for row in result.list()
					expect(row.record["age"] >= lastAge).toBeTruthy()
					lastAge = row.record["age"]

				@database.drop("test")

			.then -> done()


	it "should sort a result set descending", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (ids) =>
				@collection.all()

			.then (result) =>
				result = result.sort(collections.fn.sortDescending("age"))
				lastAge = 9999
				for row in result.list()
					expect(row.record["age"] <= lastAge).toBeTruthy()
					lastAge = row.record["age"]

				@database.drop("test")

			.then -> done()


	it "should filter for a match using the provided 'is' function", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (ids) =>
				@collection.all()

			.then (result) =>
				result = result.filter(collections.fn.is("name", "Bob"))
				expect(result.length).toBe(1)
				expect(result.records[0].record["name"]).toBe("Bob")

				@database.drop("test")

			.then -> done()


	it "should update a record correctly", (done) ->
		savedRecord = null

		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addOneRecord(@collection)

			.then (@id) =>
				@collection.all()

			.then (result) =>
				savedRecord = result.next()
				savedRecord.record["name"] = "Gemma"
				@collection.update(savedRecord)

			.then =>
				@collection.all()

			.then (result) =>
				updatedRecord = result.next()
				expect(updatedRecord.id).toBe(@id)
				expect(updatedRecord.record["name"]).toBe("Gemma")
				expect(updatedRecord.record["age"]).toBe(savedRecord.record["age"])

				@database.drop("test")

			.then -> done()


	it "should fail to update a record without id", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				@collection.update(record: name: "Gemma", age: 24)

			.catch (reason) ->
				expect(reason.message).toBe("Can't update a record without an 'id' property.")

			.then =>
				@database.drop("test")

			.then -> done()


	it "should fail to update a non existant record", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				@collection.update(id: 1, record: name: "Gemma", age: 24)

			.catch (reason) ->
				expect(reason.message).toBe("Can't update this record. It's not in the database.")

			.then =>
				@database.drop("test")

			.then -> done()


	it "should not complain about removing non existant records", ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				@collection.remove(1)

			.then (result) =>
				@database.drop("test")

			.then -> done()



	it "should pass an object to filter function when querying an index", (done) ->
		fns = fn: (key) -> true
		spyOn(fns, 'fn')

		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addSomeRecords(@collection)

			.then (ids) =>
				@collection.index("name")

			.then (index) ->
				index.query(fns.fn)

			.then (result) =>
				expect(fns.fn).toHaveBeenCalledWith(name: "Bob")
				@database.drop("test")

			.then -> done()


	it "should not change a record in the database without explicit update", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.collection("test")

			.then (@collection) =>
				addOneRecord(@collection)

			.then (@id) =>
				@collection.get(@id)

			.then (result) =>
				name = result.record["name"]
				result.record["name"] = "George"
				@collection.get(@id)

			.then (result) =>
				expect(result.record.name).not.toBe("George")
				@database.drop("test")

			.then -> done()


	it "should add a one-direction filter", (done) ->
				(new collections.Database()).initialize()
					.then (@database) =>
						@database.filters.in = [
							(record) ->
								record.lastModified = Math.floor(Date.now() / 1000)
								Promise.resolve(record)
						]
						@database.collection("test")

					.then (@collection) =>
						addOneRecord(@collection)

					.then (@id) =>
						@collection.get(@id)

					.then (result) =>
						expect(result.record.lastModified).toBeGreaterThan(0)
						@database.drop("test")

					.then -> done()


	it "should add multiple filters that are executed in sequence", (done) ->
				(new collections.Database()).initialize()
					.then (@database) =>
						@database.filters.in = [
							(record) ->
								record.tag = "one"
								Promise.resolve(record)

							(record) ->
								record.tag += " two"
								Promise.resolve(record)
						]
						@database.collection("test")

					.then (@collection) =>
						addOneRecord(@collection)

					.then (@id) =>
						@collection.get(@id)

					.then (result) =>
						expect(result.record.tag).toEqual("one two")
						@database.drop("test")

					.then -> done()


	it "should add an out filter correctly", (done) ->
				(new collections.Database()).initialize()
					.then (@database) =>
						@database.filters.out = [
							(record) ->
								record.age *= 2
								Promise.resolve(record)
						]
						@database.collection("test")

					.then (@collection) =>
						addOneRecord(@collection)

					.then (@id) =>
						@collection.get(@id)

					.then (result) =>
						expect(result.record.age).toEqual(record.age * 2)
						@database.drop("test")

					.then -> done()
