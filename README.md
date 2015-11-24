collections [![Build Status](https://travis-ci.org/privatwolke/collections.coffee.svg?branch=master)](https://travis-ci.org/privatwolke/collections.coffee)
=====================================================================================

A NoSQL solution written in pure CoffeeScript. Can optionally use LocalStorage
for persistency. But it can also run only in memory.


Building and Testing
--------------------

`npm install && npm test`


Usage
-----

`collections.coffee` uses Promises for every operation that could potentially
take some time.

``` coffee
(new collections.Database()).initialize()
	.then (@database) =>
		@database.collection("recipes")

	.then (@collection) =>
		@collection.add(name: "Bacon and Eggs", ingredients: ["bacon", "eggs"])

	.then (@id) =>
		console.log "Added recipe with ID #{@id}!"
```

Check out [the unit tests](spec/collectionSpec.coffee) for more!
