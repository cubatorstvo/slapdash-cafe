extends Node
## Records are immutable after acceptance. Only small metadata is copied on the main thread.
var worker: Thread
var pending := {}
var path := ""
var last_error := OK
var last_write_ms := 0
var writes := 0

func request(data: Dictionary, target: String) -> void:
	pending = data
	path = target
	_launch_pending()

func _process(_delta: float) -> void:
	if worker != null and not worker.is_alive(): _join()
	_launch_pending()

func _launch_pending() -> void:
	if worker != null or pending.is_empty(): return
	var data := pending
	pending = {}
	worker = Thread.new()
	var error := worker.start(_write.bind(data, path))
	if error != OK:
		last_error = error
		worker = null
		pending = data

static func _write(data: Dictionary, target: String) -> Dictionary:
	var started := Time.get_ticks_msec()
	var bytes := var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE)
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null: return {"error": FileAccess.get_open_error(), "ms": 0}
	file.store_buffer(bytes)
	var error := file.get_error()
	file.close()
	if error == OK: error = DirAccess.rename_absolute(target + ".tmp", target)
	return {"error": error, "ms": Time.get_ticks_msec() - started}

func _join() -> void:
	var report: Dictionary = worker.wait_to_finish()
	worker = null
	last_error = report.error
	last_write_ms = report.ms
	writes += 1
	if last_error != OK: push_error("Cafe save failed: " + error_string(last_error))

func flush() -> void:
	if worker != null: _join()
	_launch_pending()
	if worker != null: _join()

func _exit_tree() -> void: flush()
