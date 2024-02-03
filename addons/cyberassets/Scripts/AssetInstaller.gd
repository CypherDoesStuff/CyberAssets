@tool
extends Node

static func download(assetUrl : String, assetId : String, downloadRequest : HTTPRequest) -> String:
	if !assetUrl.is_empty():
		#blah blah download
		print("downloading!")
		downloadRequest.cancel_request()

		var assetPath = EditorInterface.get_editor_paths().get_cache_dir().path_join(str("tmp_asset_", assetId, ".zip"))
		downloadRequest.download_file = assetPath
		downloadRequest.request(assetUrl)

		var result = await downloadRequest.request_completed

		if result[0] == OK:
			return assetPath
		pass
	return ""

static func install_from_zip(path : String, ignoreRoot : bool, installDirs : Dictionary):
	var reader = ZIPReader.new()
	var error = reader.open(path)

	if error == OK:
		var installDir = EditorInterface.get_editor_paths().get_cache_dir().path_join("temp_testing")
		error = DirAccess.make_dir_absolute(installDir)
		if DirAccess.dir_exists_absolute(installDir):
			var assetFiles = reader.get_files()

			for dir in assetFiles:
				var assetDir = dir
				if ignoreRoot:			
					assetDir = dir.replace(assetFiles[0], "")

				if assetDir.is_empty():
					continue
				if installDirs[dir]:
					if !assetDir.ends_with("/"):
						var file := FileAccess.open(installDir.path_join(assetDir), FileAccess.WRITE)
						if file:
							file.store_buffer(reader.read_file(dir))
					else:
						error = DirAccess.make_dir_absolute(installDir.path_join(assetDir))
						if error != OK:
							print(str("error", error))
		
	else:
		printerr("CyberAsset: Failed to download asset")

	reader.close()

static func get_zip_files_from_path(path : String) -> Array:
	var reader = ZIPReader.new()
	var error = reader.open(path)
	var assetFiles = []

	if error == OK:
		assetFiles = reader.get_files()

	reader.close()
	return assetFiles

			
