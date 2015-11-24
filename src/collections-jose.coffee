jose = require "node-jose"

signRecord = (key) -> (record) ->
	jose.JWS.createSign(key).update(JSON.stringify(record)).final()

verifyRecord = (keystore) -> (record) ->
	jose.JWS.createVerify(keystore).verify(record)
		.then (result) ->
			JSON.parse(result.payload)

encryptRecord = (key) -> (record) ->
	jose.JWE.createEncrypt(key).update(JSON.stringify(record)).final()

decryptRecord = (keystore) -> (record) ->
	jose.JWE.createDecrypt(keystore).decrypt(record)
		.then (result) ->
			JSON.parse(result.plaintext)

if exports?
	exports.signRecord = signRecord
	exports.verifyRecord = verifyRecord
	exports.encryptRecord = encryptRecord
	exports.decryptRecord = decryptRecord
