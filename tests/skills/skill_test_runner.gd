extends Node
## Skill Test Runner — executes all skill tests sequentially and reports results.
## Run: godot --headless --path . tests/skills/skill_test_runner.tscn
## Run single: godot --headless --path . tests/skills/skill_test_runner.tscn -- --skill=fireball

const SkillTestBaseScript: GDScript = preload("res://tests/skills/skill_test_base.gd")

var _test_scripts: Array = []
var _current_test_idx: int = -1
var _current_test: Node = null
var _results: Array[Dictionary] = []  # {name, passed, message}
var _filter_skill: String = ""
var _startup_delay: float = 0.5  # Wait for autoloads to initialize
var _startup_timer: float = 0.0
var _started: bool = false

func _ready() -> void:
	# Parse command line for --skill=name filter
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--skill="):
			_filter_skill = arg.substr(8)
			print("[SkillTestRunner] Filtering to skill: %s" % _filter_skill)

	# Discover test scripts
	_discover_tests()
	print("[SkillTestRunner] Found %d skill tests" % _test_scripts.size())

func _process(delta: float) -> void:
	# Wait for autoloads to be ready
	if not _started:
		_startup_timer += delta
		if _startup_timer < _startup_delay:
			return
		_started = true
		_run_next_test()
		return

func _discover_tests() -> void:
	var dir := DirAccess.open("res://tests/skills/")
	if not dir:
		push_error("[SkillTestRunner] Cannot open tests/skills/ directory")
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.begins_with("test_") and file.ends_with(".gd"):
			var script_path := "res://tests/skills/%s" % file
			var script := load(script_path)
			if script:
				# Create temp instance to check it and get skill name
				var instance := Node.new()
				instance.set_script(script)
				if instance.has_method("get_skill_name"):
					var sname: String = instance.get_skill_name()
					if _filter_skill == "" or sname == _filter_skill:
						_test_scripts.append({"script": script, "name": sname})
				instance.free()
		file = dir.get_next()
	dir.list_dir_end()

	# Sort by name for consistent ordering
	_test_scripts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"] < b["name"]
	)

func _run_next_test() -> void:
	_current_test_idx += 1

	if _current_test_idx >= _test_scripts.size():
		_print_summary()
		return

	var test_info: Dictionary = _test_scripts[_current_test_idx]
	_current_test = Node.new()
	_current_test.set_script(test_info["script"])
	add_child(_current_test)

	_current_test.test_completed.connect(_on_test_completed)
	print("[%d/%d] Running: %s ..." % [_current_test_idx + 1, _test_scripts.size(), test_info["name"]])
	_current_test.run_test()

func _on_test_completed(test_name: String, passed: bool, message: String) -> void:
	var status := "PASS" if passed else "FAIL"
	print("  [%s] %s — %s" % [status, test_name, message])

	_results.append({"name": test_name, "passed": passed, "message": message})

	# Clean up current test
	if is_instance_valid(_current_test):
		_current_test.test_completed.disconnect(_on_test_completed)
		_current_test.queue_free()
		_current_test = null

	# Wait a frame then run next
	await get_tree().process_frame
	await get_tree().process_frame
	_run_next_test()

func _print_summary() -> void:
	print("")
	print("=".repeat(60))
	print("SKILL TEST RESULTS")
	print("=".repeat(60))

	var pass_count := 0
	var fail_count := 0

	for r in _results:
		if r["passed"]:
			pass_count += 1
		else:
			fail_count += 1
			print("  FAIL: %s — %s" % [r["name"], r["message"]])

	print("")
	print("Total: %d | Pass: %d | Fail: %d" % [_results.size(), pass_count, fail_count])
	print("=".repeat(60))

	# Exit with code
	if fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
