class Database
	constructor: (@options = {}) ->
		# default options
		@options.prefix  = @options.prefix  ? "__COLLECTION__"
		@options.persist = @options.persist ? true

		@data = {}

		for key of localStorage
			if key[0 .. @options.prefix.length - 1] is @options.prefix
				collection = JSON.parse(localStorage[key])
				@data[key[@options.prefix.length .. key.length]] = collection


	collection: (name) ->
		new Collection(name, @)


	collections: ->
		result = {}
		for key of @data
			result[key] = new Collection(key, @)
		return result


	drop: (collectionName) ->
		delete @data[collectionName]
		delete localStorage[@options.prefix + collectionName]


	commit: (collectionName) ->
		if @options.persist
			collection = JSON.stringify(@data[collectionName])
			localStorage[@options.prefix + collectionName] = collection

		return true



class Collection
	constructor: (@name, @database) ->
		# create the collection if it does not exist
		if not @database.data[@name]
			@database.data[@name] =
				id: 0
				indices: {}
				records: {}

		@indices = {}
		for i of @database.data[@name].indices
			@indices[i] = new Index(@database, @name, i)


	id: ->
		++@database.data[@name].id


	commit: ->
		@database.commit(@name)


	all: ->
		result = []
		for id, record of @database.data[@name].records
			result.push(
				"id": parseInt(id)
				"record": DBUtils.clone(@database.data[@name].records[id])
			)

		return new RecordSet(result)


	index: (indexSpec) ->
		@indices[indexSpec] = new Index(@database, @name, indexSpec)


	get: (id) ->
		record = DBUtils.clone(@database.data[@name].records[id])

		if DBUtils.isEmpty(record)
			return null
		else
			return "id": id, "record": record


	# funcFilter(key) -- argument is an excerpt from the record with correct types
	query: (indexSpec, funcFilter) ->
		index = @database.data[@name].indices[indexSpec]
		records = []
		for key of index
			if funcFilter(JSON.parse(key))
				for id in index[key]
					records.push(
						"id": id
						"record": DBUtils.clone(@database.data[@name].records[id])
					)

		return new RecordSet(records)


	filter: (funcFilter) ->
		new RecordSet(@all()).filter(funcFilter)


	sort: (funcFilter) ->
		new RecordSet(@all()).sort(funcSort)


	add: (record) ->
		records = DBUtils.toArray(record)
		ids = []

		for r in records
			id = @id()
			@database.data[@name].records[id] = DBUtils.clone(r)

			# update all indices
			for indexSpec of @indices
				@indices[indexSpec].add(id, r)

			ids.push(id)

		# commit the changes to localStorage
		@commit()

		return if records.length is 1 then ids[0] else ids


	update: (record) ->
		id = record.id
		record = record.record

		# refuse to update something without an id
		if not id?
			throw new Error("Can't update a record without an 'id' property.")

		# refuse to update something that is not already in the database
		if not @database.data[@name].records[id]?
			throw new Error("Can't update this record. It's not in the database.")

		# update all indices
		for indexSpec of @indices
			@indices[indexSpec].remove(id)
			@indices[indexSpec].add(id, record)

		@database.data[@name].records[id] = DBUtils.clone(record)

		# commit the changes to localStorage
		@commit()

		return id


	remove: (id) ->
		# update indices
		for index of @indices
			@indices[index].remove(id)

		# remove from the datastore
		delete @database.data[@name].records[id]

		# commit the changes to localStorage
		@commit()

		return true



class Index
	constructor: (@database, @name, @indexSpec) ->
		@database.data[@name].indices[@indexSpec] = {}

		for id, record of @database.data[@name].records
			@add(id, record)


	value: (record) ->
		result = {}
		for field in @indexSpec.split(",")
			if not field in record
				return null
			else
				result[field] = record[field]

		return JSON.stringify(result)


	add: (id, record) ->
		value = @value(record)

		if value
			if @database.data[@name].indices[@indexSpec][value]
				@database.data[@name].indices[@indexSpec][value].push(id)
			else
				@database.data[@name].indices[@indexSpec][value] = [id]


	remove: (id) ->
		record = @database.data[@name].records[id]
		value = @value(record)
		index = @database.data[@name].indices[@indexSpec][value].indexOf(id)
		@database.data[@name].indices[@indexSpec][value].splice(index, 1)



class RecordSet
	constructor: (@records) ->

		@length = parseInt(@records.length)
		@cursor = 0


	list: -> @records


	next: ->
		if @cursor >= @length
			return undefined

		@records[@cursor++]


	rewind: ->
		@cursor = 0


	seek: (pos) ->
		@cursor = pos


	limit: (num) ->
		new RecordSet(@records[0 .. num - 1])


	# funcSort({"id": 0, "record": { ... }})
	sort: (funcSort) ->
		new RecordSet(@records.sort(funcSort))


	shuffle: ->
		# adapted from https://github.com/coolaj86/knuth-shuffle
		currentIndex = @records.length

		while currentIndex != 0
			randomIndex = Math.floor(Math.random() * currentIndex)
			currentIndex--

			temporaryValue = @records[currentIndex]
			@records[currentIndex] = @records[randomIndex]
			@records[randomIndex] = temporaryValue

		new RecordSet(@records)


	# funcFilter({"id": 0, "record": { ... }})
	filter: (funcFilter) ->
		filtered = []
		for record in @records
			if funcFilter(record)
				filtered.push(record)

		new RecordSet(filtered)



class DBUtils
	@clone: (record) ->
		target = {}
		for own key, value of record
			target[key] = value
		return target

	@isEmpty: (obj) ->
		for key, value of obj
			return false
		return true

	@toArray: (o) ->
		if Object.prototype.toString.call(o) is "[object Array]"
			return o
		else
			return [o]



class DatabaseFunctions
	@sortAscending: (field) ->
		(a, b) ->
			if      a.record[field] > b.record[field] then  1
			else if a.record[field] < b.record[field] then -1
			else    0

	@sortDescending: (field) ->
		(a, b) ->
			if      a.record[field] < b.record[field] then  1
			else if a.record[field] > b.record[field] then -1
			else    0

	@is: (field, value) ->
		(record) -> record.record[field] is value


if exports?
	exports.Database = Database
	exports.fn =
		is: DatabaseFunctions.is
		sortAscending: DatabaseFunctions.sortAscending
		sortDescending: DatabaseFunctions.sortDescending
