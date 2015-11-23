iterator = `function*(arr) {
  var i, len, results, value;
  results = [];
  for (i = 0, len = arr.length; i < len; i++) {
    value = arr[i];
    results.push((yield value));
  }
  return results;
};`


class Database
	constructor: (@options = {}) ->
		# default options
		@options.prefix  = @options.prefix  ? "__COLLECTION__"
		@options.persist = @options.persist ? true

		@data = {}
		@filters = {in: [], out: []}


	initialize: ->
		new Promise (resolve) =>
			if @options.persist
				for key of localStorage
					if key[0 .. @options.prefix.length - 1] is @options.prefix
						collection = JSON.parse(localStorage[key])
						@data[key[@options.prefix.length .. key.length]] = collection

			resolve(@)


	collection: (name) ->
		new Promise (resolve) =>
			resolve(new Collection(name, @))


	collections: ->
		new Promise (resolve) =>
			result = {}
			for key of @data
				result[key] = new Collection(key, @)
			resolve(result)


	drop: (collectionName) ->
		new Promise (resolve) =>
			delete @data[collectionName]
			delete localStorage[@options.prefix + collectionName]
			resolve()


	commit: (collectionName) ->
		new Promise (resolve) =>
			if @options.persist
				collection = JSON.stringify(@data[collectionName])
				localStorage[@options.prefix + collectionName] = collection

			resolve(true)


	__addFilters: (id, record) ->
		DBUtils.applyFilters(id, record, @filters.in)


	__removeFilters: (id, record) ->
		DBUtils.applyFilters(id, record, @filters.out)



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
		new Promise (resolve) =>
			promises = []
			for id, record of @database.data[@name].records
				promises.push @database.__removeFilters(id, record)
					.then (result) ->
						return {
							"id": parseInt(result.id)
							"record": result.record
						}

			Promise.all(promises)
				.then (values) ->
					resolve(new RecordSet(values))


	index: (indexSpec) ->
		new Promise (resolve) =>
			@indices[indexSpec] = new Index(@database, @name, indexSpec)
			resolve(@indices[indexSpec])


	get: (id) ->
		new Promise (resolve) =>
			record = DBUtils.clone(@database.data[@name].records[id])

			if DBUtils.isEmpty(record)
				resolve(null)
			else
				@database.__removeFilters(id, record)
					.then (result) ->
						resolve(id: result.id, record: result.record)


	add: (record) ->
		new Promise (resolve) =>
			records = DBUtils.toArray(record)
			promises = []
			ids = []

			for r in records
				promises.push @database.__addFilters(@id(), DBUtils.clone(r))
					.then (result) =>
						id = result.id
						@database.data[@name].records[id] = result.record

						# update all indices
						for indexSpec of @indices
							@indices[indexSpec].add(id, result.original)

						return id

			Promise.all(promises)
				.then (values) =>
					ids = values
					@commit()
				.then ->
					resolve(if ids.length is 1 then ids[0] else ids)


	update: (record) ->
		new Promise (resolve, reject) =>
			id = record.id
			record = record.record

			# refuse to update something without an id
			if not id?
				reject(new Error("Can't update a record without an 'id' property."))

			# refuse to update something that is not already in the database
			if not @database.data[@name].records[id]?
				reject(new Error("Can't update this record. It's not in the database."))

			@database.__addFilters(id, DBUtils.clone(record))
				.then (result) =>
					@database.data[@name].records[result.id] = result.record
					# update all indices
					for indexSpec of @indices
						@indices[indexSpec].remove(result.id)
						@indices[indexSpec].add(result.id, result.original)

					@commit()

				.then -> resolve(id)


	remove: (id) ->
		new Promise (resolve) =>
			# update indices
			for index of @indices
				@indices[index].remove(id)

			# remove from the datastore
			delete @database.data[@name].records[id]

			# commit the changes to localStorage
			@commit().then -> resolve(true)



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


	# funcFilter(key) -- argument is an excerpt from the record with correct types
	query: (funcFilter) ->
		new Promise (resolve) =>
			index = @database.data[@name].indices[@indexSpec]
			promises = []

			for key of index
				if funcFilter(JSON.parse(key))
					for id in index[key]
						promises.push @database.__removeFilters(
							id, DBUtils.clone(@database.data[@name].records[id])
						).then (result) ->
							return {
								"id": result.id
								"record": result.record
							}

			Promise.all(promises)
				.then (records) ->
					resolve(new RecordSet(records))



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

	@applyFilters = (id, record, fns) ->
		fns = iterator(fns)
		fn = fns.next()
		original = DBUtils.clone(record)

		recurse = (fn, record) ->
			fn.value(record)
				.then (record) ->
					fn = fns.next()
					if not fn.done
						return recurse(fn, record)
					else
						return Promise.resolve(id: id, record: record, original: original)

		if fn.done
			return Promise.resolve(id: id, record: record, original: original)
		else
			return recurse(fn, record)



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
