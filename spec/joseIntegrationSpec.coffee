collections = require "../src/collections"
collections_jose = require "../src/collections-jose"
jose = require "node-jose"


describe "JOSE Integration Test Suite", ->

	record = name: "Gemma", age: 24

	inputKey = {
		kty: 'oct'
		kid: 'c93a540b-cb2d-4ebe-b8fa-b7d63a2da4a0'
		k: 'TLznmW6vAmqYQPBAwYrKIg6WZyIpwMVZrMCm3Xc1m1o'
	}

	beforeEach (done) ->
		@keystore = jose.JWK.createKeyStore()
		@keystore.add(inputKey)
			.then (@key) =>
				done()

	afterEach ->
		delete @key
		delete @keystore


	it "should have jose", ->
		expect(@keystore).toBeDefined()
		expect(@key).toBeDefined()


	it "should sign", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.filters.in  = [collections_jose.signRecord(@key)]
				@database.filters.out = [collections_jose.verifyRecord(@keystore)]
				@database.collection("test")

			.then (@collection) =>
				@collection.add(record)

			.then (@id) =>
				expect(@database.data.test.records["#{@id}"].payload).toBeDefined()
				expect(@database.data.test.records["#{@id}"].signatures).toBeDefined()
				expect(@database.data.test.records["#{@id}"].name).not.toBeDefined()
				@collection.get(@id, false)

			.then (plainResult) =>
				expect(plainResult).not.toEqual(record)
				@collection.get(@id)

			.then (result) =>
				expect(result.record).toEqual(record)
				@database.drop("test")

			.then -> done()


	it "should encrypt", (done) ->
		(new collections.Database()).initialize()
			.then (@database) =>
				@database.filters.in  = [collections_jose.encryptRecord(@key)]
				@database.filters.out = [collections_jose.decryptRecord(@keystore)]
				@database.collection("test")

			.then (@collection) =>
				@collection.add(record)

			.then (@id) =>
				expect(@database.data.test.records["#{@id}"].ciphertext).toBeDefined()
				@collection.get(@id, false)

			.then (plainResult) =>
				expect(plainResult).not.toEqual(record)
				@collection.get(@id)

			.then (result) =>
				expect(result.record).toEqual(record)
				@database.drop("test")

			.then -> done()
