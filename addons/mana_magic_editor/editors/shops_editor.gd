@tool
extends "res://addons/mana_magic_editor/editors/base_editor.gd"

## Shop editor with interactive item/equipment selection from the database.

var _items_db: Array = []
var _equip_db: Array = []

var _f_seller_id: LineEdit
var _f_discount: SpinBox

# Shop items table
var _items_container: VBoxContainer
var _items_rows: Array = []  # Array of {hbox, id_label, name_label, price_spin, stock_spin, data_index}

# Shop equipment table
var _equip_container: VBoxContainer
var _equip_rows: Array = []

func _get_json_filename() -> String:
	return "shops.json"

func _get_display_name(entry: Dictionary) -> String:
	return "%s - %s" % [entry.get("id", "?"), entry.get("sellerId", "unknown")]

func _build_form() -> void:
	_items_db = ManaJsonHelper.load_json("items.json")
	_equip_db = ManaJsonHelper.load_json("equipments.json")

	_add_section_label("Shop Info")
	_f_seller_id = _create_line_edit("e.g. neko_01")
	_add_field("Seller ID:", _f_seller_id)
	_f_discount = _create_spin(0, 100)
	_add_number_field("Discount %:", _f_discount)

	_add_spacer()
	_add_section_label("Shop Items")
	_build_shop_table_header("items")
	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_container.add_child(_items_container)
	var btn_add_item := Button.new()
	btn_add_item.text = "+ Add Item..."
	btn_add_item.pressed.connect(_on_add_item_pressed)
	_form_container.add_child(btn_add_item)

	_add_spacer()
	_add_section_label("Shop Equipment")
	_build_shop_table_header("equipment")
	_equip_container = VBoxContainer.new()
	_equip_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_container.add_child(_equip_container)
	var btn_add_equip := Button.new()
	btn_add_equip.text = "+ Add Equipment..."
	btn_add_equip.pressed.connect(_on_add_equip_pressed)
	_form_container.add_child(btn_add_equip)

func _build_shop_table_header(type: String) -> void:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl_name := Label.new()
	lbl_name.text = "Name"
	lbl_name.custom_minimum_size.x = 180
	header.add_child(lbl_name)
	var lbl_price := Label.new()
	lbl_price.text = "Price"
	lbl_price.custom_minimum_size.x = 80
	header.add_child(lbl_price)
	var lbl_stock := Label.new()
	lbl_stock.text = "Stock"
	lbl_stock.custom_minimum_size.x = 80
	header.add_child(lbl_stock)
	var lbl_action := Label.new()
	lbl_action.text = ""
	lbl_action.custom_minimum_size.x = 60
	header.add_child(lbl_action)
	_form_container.add_child(header)
	var sep := HSeparator.new()
	_form_container.add_child(sep)

func _populate_form(entry: Dictionary) -> void:
	_f_seller_id.text = str(entry.get("sellerId", ""))
	_f_discount.value = entry.get("discount", 0)
	_rebuild_items_table(entry.get("items", []))
	_rebuild_equip_table(entry.get("equipment", []))

func _collect_form_data() -> Dictionary:
	return {
		"sellerId": _f_seller_id.text,
		"discount": int(_f_discount.value),
		"items": _collect_table_data(_items_rows),
		"equipment": _collect_table_data(_equip_rows),
	}

func _create_default_entry(id: int) -> Dictionary:
	return {
		"id": id, "sellerId": "new_shop",
		"discount": 0, "items": [], "equipment": [],
	}

# --- Items table ---

func _rebuild_items_table(items: Array) -> void:
	# Clear existing rows
	for row in _items_rows:
		row["hbox"].queue_free()
	_items_rows.clear()

	for item in items:
		if item is Dictionary:
			_add_item_row(int(item.get("itemId", 0)), int(item.get("price", 0)), int(item.get("stock", -1)))

func _add_item_row(item_id: int, price: int, stock: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Name label (resolved from DB)
	var name_label := Label.new()
	name_label.custom_minimum_size.x = 180
	name_label.text = _resolve_item_name(item_id)
	name_label.tooltip_text = "ID: %d" % item_id
	hbox.add_child(name_label)

	# Price spin
	var price_spin := SpinBox.new()
	price_spin.min_value = -1
	price_spin.max_value = 999999
	price_spin.value = price
	price_spin.custom_minimum_size.x = 80
	hbox.add_child(price_spin)

	# Stock spin
	var stock_spin := SpinBox.new()
	stock_spin.min_value = -1
	stock_spin.max_value = 9999
	stock_spin.value = stock
	stock_spin.custom_minimum_size.x = 80
	stock_spin.tooltip_text = "-1 = unlimited"
	hbox.add_child(stock_spin)

	# Remove button
	var btn_remove := Button.new()
	btn_remove.text = "X"
	btn_remove.custom_minimum_size.x = 40
	var row_ref := {"hbox": hbox, "item_id": item_id, "name_label": name_label, "price_spin": price_spin, "stock_spin": stock_spin}
	btn_remove.pressed.connect(_on_remove_item_row.bind(row_ref))
	hbox.add_child(btn_remove)

	_items_container.add_child(hbox)
	_items_rows.append(row_ref)

func _on_remove_item_row(row: Dictionary) -> void:
	var idx := _items_rows.find(row)
	if idx >= 0:
		_items_rows.remove_at(idx)
		row["hbox"].queue_free()

func _on_add_item_pressed() -> void:
	_show_picker_dialog("Select Item", _items_db, func(entry: Dictionary):
		var item_id: int = int(entry.get("id", 0))
		var price: int = int(entry.get("price", 0))
		_add_item_row(item_id, price, -1)
	)

# --- Equipment table ---

func _rebuild_equip_table(equips: Array) -> void:
	for row in _equip_rows:
		row["hbox"].queue_free()
	_equip_rows.clear()

	for eq in equips:
		if eq is Dictionary:
			_add_equip_row(int(eq.get("itemId", 0)), int(eq.get("price", 0)), int(eq.get("stock", -1)))

func _add_equip_row(item_id: int, price: int, stock: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.custom_minimum_size.x = 180
	name_label.text = _resolve_equip_name(item_id)
	name_label.tooltip_text = "ID: %d" % item_id
	hbox.add_child(name_label)

	var price_spin := SpinBox.new()
	price_spin.min_value = -1
	price_spin.max_value = 999999
	price_spin.value = price
	price_spin.custom_minimum_size.x = 80
	hbox.add_child(price_spin)

	var stock_spin := SpinBox.new()
	stock_spin.min_value = -1
	stock_spin.max_value = 9999
	stock_spin.value = stock
	stock_spin.custom_minimum_size.x = 80
	stock_spin.tooltip_text = "-1 = unlimited"
	hbox.add_child(stock_spin)

	var btn_remove := Button.new()
	btn_remove.text = "X"
	btn_remove.custom_minimum_size.x = 40
	var row_ref := {"hbox": hbox, "item_id": item_id, "name_label": name_label, "price_spin": price_spin, "stock_spin": stock_spin}
	btn_remove.pressed.connect(_on_remove_equip_row.bind(row_ref))
	hbox.add_child(btn_remove)

	_equip_container.add_child(hbox)
	_equip_rows.append(row_ref)

func _on_remove_equip_row(row: Dictionary) -> void:
	var idx := _equip_rows.find(row)
	if idx >= 0:
		_equip_rows.remove_at(idx)
		row["hbox"].queue_free()

func _on_add_equip_pressed() -> void:
	_show_picker_dialog("Select Equipment", _equip_db, func(entry: Dictionary):
		var item_id: int = int(entry.get("id", 0))
		var price: int = int(entry.get("price", 0))
		_add_equip_row(item_id, price, -1)
	)

# --- Picker dialog ---

func _show_picker_dialog(title: String, db: Array, on_select: Callable) -> void:
	var dialog := Window.new()
	dialog.title = title
	dialog.size = Vector2i(400, 500)
	dialog.transient = true
	dialog.exclusive = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	dialog.add_child(vbox)

	# Search
	var search := LineEdit.new()
	search.placeholder_text = "Search..."
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(search)

	# List
	var picker_list := ItemList.new()
	picker_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(picker_list)

	# Populate
	var filtered_db: Array = []
	for entry in db:
		if not entry is Dictionary:
			continue
		var section = str(entry.get("section", ""))
		# Skip MAGIC/ETC items for item picker
		if section == "MAGIC" or section == "ETC":
			continue
		filtered_db.append(entry)

	var _populate_picker := func(filter_text: String = ""):
		picker_list.clear()
		var search_lower := filter_text.to_lower()
		for entry in filtered_db:
			var display_name: String = str(entry.get("nameText", entry.get("name", "?")))
			var display := "%s - %s" % [entry.get("id", "?"), display_name]
			if search_lower != "" and display.to_lower().find(search_lower) == -1:
				continue
			picker_list.add_item(display)
			picker_list.set_item_metadata(picker_list.item_count - 1, entry)

	_populate_picker.call("")
	search.text_changed.connect(func(text: String): _populate_picker.call(text))

	# Buttons
	var btn_bar := HBoxContainer.new()
	vbox.add_child(btn_bar)
	var btn_ok := Button.new()
	btn_ok.text = "Select"
	btn_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_bar.add_child(btn_ok)
	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_bar.add_child(btn_cancel)

	btn_ok.pressed.connect(func():
		var selected := picker_list.get_selected_items()
		if not selected.is_empty():
			var entry: Dictionary = picker_list.get_item_metadata(selected[0])
			on_select.call(entry)
		dialog.queue_free()
	)
	btn_cancel.pressed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

	# Double-click to select
	picker_list.item_activated.connect(func(index: int):
		var entry: Dictionary = picker_list.get_item_metadata(index)
		on_select.call(entry)
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()

# --- Data helpers ---

func _collect_table_data(rows: Array) -> Array:
	var result := []
	for row in rows:
		result.append({
			"itemId": row["item_id"],
			"price": int(row["price_spin"].value),
			"stock": int(row["stock_spin"].value),
		})
	return result

func _resolve_item_name(item_id: int) -> String:
	for entry in _items_db:
		if entry is Dictionary and int(entry.get("id", -1)) == item_id:
			return "[%d] %s" % [item_id, entry.get("nameText", entry.get("name", "?"))]
	return "[%d] ???" % item_id

func _resolve_equip_name(item_id: int) -> String:
	for entry in _equip_db:
		if entry is Dictionary and int(entry.get("id", -1)) == item_id:
			return "[%d] %s" % [item_id, entry.get("nameText", entry.get("name", "?"))]
	return "[%d] ???" % item_id
