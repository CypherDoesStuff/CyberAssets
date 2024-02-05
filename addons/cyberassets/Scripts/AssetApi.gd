extends Node

var queueState = imageQueueState.new()

func request_assets(apiUrl : String, apiRequest : HTTPRequest, page: int, filter : String = "", category : String = "", version : String = "4", sort : String = "updated", reverse : bool = false, support: Array = [true,true,false]) -> Variant:	
	var requestUrl := apiUrl.path_join("asset?page={page}&filter={fil}&category={cat}&godot_version={ver}&cost=&sort={sort}").format(
	{
		"page":page,
		"fil":filter,
		"cat":category,
		"ver":version,
		"sort":sort,
	})

	if support[0]:
		requestUrl = str(requestUrl, "&support[official]=1")
	if support[1]:
		requestUrl = str(requestUrl, "&support[community]=1")
	if support[2]:
		requestUrl = str(requestUrl, "&support[testing]=1")

	if reverse:
		requestUrl = str(requestUrl, "&reverse")

	apiRequest.cancel_request()
	apiRequest.request(requestUrl, ["User-Agent: CyberAssets", "Accept: application/vnd.github.v3+json"], HTTPClient.METHOD_GET, "")

	var result : Array = await apiRequest.request_completed

	if result[0] == OK:
		var responseData : String = result[3].get_string_from_utf8()
		var json : JSON = JSON.new()
		var error : int = json.parse(responseData)

		var assets : Array = json.data["result"]

		if error == OK:	
			var resultMaxPage : int = json.data["pages"]
			
			return json.data
		else:
			printerr("CyberAsset: Failed to parse asset lib response! Something went wrong...")
		pass
	return null

func request_asset_from_id(apiUrl : String, assetId : String, apiRequest : HTTPRequest) -> Dictionary:
	if !assetId.is_empty():
		apiRequest.cancel_request()
		apiRequest.request(apiUrl.path_join(str("asset/", assetId)))

		var result = await apiRequest.request_completed
		if result[0] == OK:
			var responseData = result[3].get_string_from_utf8()
			var json : JSON = JSON.new()
			var error : int = json.parse(responseData)
			if error == OK:
				return json.data
	return {}


func request_image(url : String, useThreads : bool, onRecieved : Callable):
	var iReq : imageRequest = imageRequest.new()
	iReq.url = url.strip_edges()
	iReq.active = false
	iReq.request = HTTPRequest.new()
	iReq.request.use_threads = useThreads
	iReq.onComplete = onRecieved
	iReq.id = queueState.imageLastId
	queueState.imageLastId += 1 

	add_child(iReq.request)

	iReq.request.request_completed.connect(image_request_complete.bind(iReq.id))
	queueState.imageQueue[iReq.id] = iReq

	image_update(true, false, [], iReq.id)
	update_image_queue()
	pass

func image_request_complete(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray, id : int):
	if !queueState.imageQueue.has(id): push_error(ERR_PARAMETER_RANGE_ERROR)
	
	if result == HTTPRequest.RESULT_SUCCESS && response_code < HTTPClient.RESPONSE_BAD_REQUEST:
		if response_code != HTTPClient.RESPONSE_NOT_MODIFIED:
			for i in headers.size():
				if headers[i].findn("ETag:") == 0:
					var cacheFilename : String = EditorInterface.get_editor_paths().get_cache_dir().path_join(str("assetimage_", queueState.imageQueue[id].url.md5_text()))
					var newEtag : String = headers[i].substr(headers[i].find(":") + 1, headers[i].length()).strip_edges()
					var file := FileAccess.open(str(cacheFilename + ".etag"), FileAccess.WRITE)
					if file:
						file.store_line(newEtag)

					file = FileAccess.open(str(cacheFilename + ".data"), FileAccess.WRITE)
					if file:
						file.store_32(body.size())
						file.store_buffer(body)
	
		image_update(response_code == HTTPClient.RESPONSE_NOT_MODIFIED, true, body, id)
	
	queueState.imageQueue[id].request.queue_free()
	queueState.imageQueue.erase(id)

	update_image_queue()


func image_update(useCache : bool, final : bool, data : PackedByteArray, id : int):
	#check cache for file data, if data, load

	var imageSet : bool
	var imageData : PackedByteArray = data

	if useCache:
		var cacheFilename : String = EditorInterface.get_editor_paths().get_cache_dir().path_join(str("assetimage_", queueState.imageQueue[id].url.md5_text()))

		var file := FileAccess.open(str(cacheFilename, ".data"), FileAccess.READ)
		if file:
			var len := file.get_32()
			imageData = file.get_buffer(len)
		pass

	var image := Image.new()

	var png_signature = PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	var jpg_signature = PackedByteArray([255, 216, 255])
	var webp_signature = PackedByteArray([82, 73, 70, 70])
	var bmp_signature = PackedByteArray([66, 77])
		
	var load_err = ERR_PARAMETER_RANGE_ERROR
	if png_signature == imageData.slice(0, 8):
		load_err = image.load_png_from_buffer(imageData)
	elif jpg_signature == imageData.slice(0, 3):
		load_err = image.load_jpg_from_buffer(imageData)
	elif webp_signature == imageData.slice(0, 4):
		load_err = image.load_webp_from_buffer(imageData)
	elif bmp_signature == imageData.slice(0, 2):
		load_err = image.load_bmp_from_buffer(imageData)
	elif imageData.size() > 0:
		load_err = image.load_svg_from_buffer(imageData)

	var requestObject = queueState.imageQueue[id].onComplete.get_object()
	if load_err == OK && !image.is_empty() && requestObject && !requestObject.is_queued_for_deletion():
		var imgTexture := ImageTexture.create_from_image(image)
		queueState.imageQueue[id].onComplete.call(imgTexture)
		imageSet = true

	pass

func update_image_queue():	
	#update image cache if nessesary
	const maxImages : int = 6
	var currentImages : int = 0

	var toDelete : Array
	for reqId in queueState.imageQueue:
		var iReq : imageRequest = queueState.imageQueue[reqId] 
		if !iReq.active && currentImages < maxImages:
			var cacheFilename : String = EditorInterface.get_editor_paths().get_cache_dir().path_join(str("assetimage_", iReq.url.md5_text()))
			var headers : PackedStringArray

			if FileAccess.file_exists(str(cacheFilename, ".etag")) && FileAccess.file_exists(str(cacheFilename, ".data")):
				var file : FileAccess = FileAccess.open(str(cacheFilename, ".etag"), FileAccess.READ)
				if file:
					headers.push_back(str("If-None-Match: ", file.get_line()))

			var error = iReq.request.request(iReq.url, headers)
			if error != OK:
				toDelete.push_back(reqId)
			else:
				iReq.active = true
			currentImages += 1
		elif iReq.active:
			currentImages += 1

	while toDelete.size():
		queueState.imageQueue[toDelete.front()].request.queue_free()
		queueState.imageQueue.erase(toDelete.pop_front())

class imageRequest:
	var url : String
	var id : int
	var request : HTTPRequest
	var active : bool
	var onComplete : Callable

class imageQueueState:
	var imageQueue : Dictionary
	var imageLastId : int