class_name HobbitSaveLoadScreen
extends Control

signal game_loaded(slot_id: int)
signal closed()

enum Mode { SAVE, LOAD }
var current_mode: Mode = Mode.SAVE
var current_page: int = 1 # 1 (слоты 1..6) или 2 (слоты 7..12)
var is_opened_from_title: bool = false
var current_screenshot: Image = null
var pending_confirm_action: Callable = Callable()
var toast_tween: Tween = null

@onready var title_label: Label = %SaveLoadTitle
@onready var btn_tab_save: Button = %BtnTabSave
@onready var btn_tab_load: Button = %BtnTabLoad
@onready var btn_close: Button = %BtnClose
@onready var btn_back_bottom: Button = %BtnBackBottom

@onready var btn_page_prev: Button = %BtnPagePrev
@onready var btn_page_next: Button = %BtnPageNext
@onready var btn_page_1: Button = %BtnPage1
@onready var btn_page_2: Button = %BtnPage2

@onready var toast_label: Label = %ToastLabel
@onready var confirm_overlay: Control = %ConfirmOverlay
@onready var confirm_prompt: Label = %ConfirmPrompt
@onready var btn_confirm_yes: Button = %BtnConfirmYes
@onready var btn_confirm_no: Button = %BtnConfirmNo

@onready var slot_cards: Array[Control] = [
	%SlotCard1,
	%SlotCard2,
	%SlotCard3,
	%SlotCard4,
	%SlotCard5,
	%SlotCard6
]

var main_ref: Node = null
var cached_game_state: Node = null
var cached_audio_manager: Node = null

func _get_game_state() -> Node:
	if cached_game_state:
		return cached_game_state
	if main_ref and "cached_game_state" in main_ref and main_ref.cached_game_state:
		return main_ref.cached_game_state
	if is_inside_tree() and get_tree().root:
		if get_tree().root.has_node("GameState"):
			return get_tree().root.get_node("GameState")
	return null

var _signals_connected: bool = false

func _ensure_nodes() -> void:
	if not title_label and has_node("%SaveLoadTitle"): title_label = %SaveLoadTitle
	if not btn_tab_save and has_node("%BtnTabSave"): btn_tab_save = %BtnTabSave
	if not btn_tab_load and has_node("%BtnTabLoad"): btn_tab_load = %BtnTabLoad
	if not btn_close and has_node("%BtnClose"): btn_close = %BtnClose
	if not btn_back_bottom and has_node("%BtnBackBottom"): btn_back_bottom = %BtnBackBottom
	if not btn_page_prev and has_node("%BtnPagePrev"): btn_page_prev = %BtnPagePrev
	if not btn_page_next and has_node("%BtnPageNext"): btn_page_next = %BtnPageNext
	if not btn_page_1 and has_node("%BtnPage1"): btn_page_1 = %BtnPage1
	if not btn_page_2 and has_node("%BtnPage2"): btn_page_2 = %BtnPage2
	if not toast_label and has_node("%ToastLabel"): toast_label = %ToastLabel
	if not confirm_overlay and has_node("%ConfirmOverlay"): confirm_overlay = %ConfirmOverlay
	if not confirm_prompt and has_node("%ConfirmPrompt"): confirm_prompt = %ConfirmPrompt
	if not btn_confirm_yes and has_node("%BtnConfirmYes"): btn_confirm_yes = %BtnConfirmYes
	if not btn_confirm_no and has_node("%BtnConfirmNo"): btn_confirm_no = %BtnConfirmNo
	if slot_cards.is_empty() or slot_cards[0] == null:
		if has_node("%SlotCard1"):
			slot_cards = [
				%SlotCard1, %SlotCard2, %SlotCard3, %SlotCard4, %SlotCard5, %SlotCard6
			]

func _ready() -> void:
	_ensure_nodes()
	visible = false
	if confirm_overlay:
		confirm_overlay.visible = false
	if toast_label:
		toast_label.modulate.a = 0.0
		
	if _signals_connected:
		return
	_signals_connected = true
		
	btn_tab_save.pressed.connect(func(): set_mode(Mode.SAVE))
	btn_tab_load.pressed.connect(func(): set_mode(Mode.LOAD))
	btn_close.pressed.connect(close)
	btn_back_bottom.pressed.connect(close)
	
	btn_page_prev.pressed.connect(func(): set_page(current_page - 1))
	btn_page_next.pressed.connect(func(): set_page(current_page + 1))
	btn_page_1.pressed.connect(func(): set_page(1))
	btn_page_2.pressed.connect(func(): set_page(2))
	
	btn_confirm_yes.pressed.connect(_on_confirm_yes)
	btn_confirm_no.pressed.connect(_on_confirm_no)
	
	for i in range(slot_cards.size()):
		var card = slot_cards[i]
		var btn_action: Button = card.get_node("%BtnCardAction" + str(i + 1))
		var btn_del: Button = card.get_node("%BtnDelete" + str(i + 1))
		
		btn_action.pressed.connect(_on_slot_card_pressed.bind(i))
		btn_del.pressed.connect(_on_slot_delete_pressed.bind(i))

func open_save(screenshot: Image = null) -> void:
	is_opened_from_title = false
	current_screenshot = screenshot
	set_mode(Mode.SAVE)
	visible = true
	if btn_close and btn_close.is_inside_tree():
		btn_close.grab_focus()

func open_load(from_title: bool = false) -> void:
	is_opened_from_title = from_title
	set_mode(Mode.LOAD)
	visible = true
	if btn_close and btn_close.is_inside_tree():
		btn_close.grab_focus()

func close() -> void:
	if confirm_overlay and confirm_overlay.visible:
		confirm_overlay.visible = false
		return
	visible = false
	closed.emit()

func close_screen() -> void:
	close()

func set_mode(new_mode: Mode) -> void:
	current_mode = new_mode
	if is_opened_from_title and current_mode == Mode.SAVE:
		current_mode = Mode.LOAD
		
	if btn_tab_save:
		btn_tab_save.visible = not is_opened_from_title
	
	var gold_col = Color(1.0, 0.85, 0.3, 1.0)
	var dim_col = Color(0.6, 0.65, 0.75, 0.7)
	
	if current_mode == Mode.SAVE:
		if title_label:
			title_label.text = "СОХРАНЕНИЕ ИГРЫ"
		if btn_tab_save:
			btn_tab_save.modulate = Color.WHITE
			btn_tab_save.add_theme_color_override("font_color", gold_col)
		if btn_tab_load:
			btn_tab_load.modulate = Color(0.8, 0.8, 0.8, 0.7)
			btn_tab_load.add_theme_color_override("font_color", dim_col)
	else:
		if title_label:
			title_label.text = "ЗАГРУЗКА ИГРЫ"
		if btn_tab_load:
			btn_tab_load.modulate = Color.WHITE
			btn_tab_load.add_theme_color_override("font_color", gold_col)
		if btn_tab_save:
			btn_tab_save.modulate = Color(0.8, 0.8, 0.8, 0.7)
			btn_tab_save.add_theme_color_override("font_color", dim_col)
		
	refresh_slots()

func set_page(p: int) -> void:
	current_page = clamp(p, 1, 2)
	if btn_page_1:
		btn_page_1.modulate = Color(1.0, 0.85, 0.3, 1.0) if current_page == 1 else Color(0.7, 0.75, 0.8, 0.7)
	if btn_page_2:
		btn_page_2.modulate = Color(1.0, 0.85, 0.3, 1.0) if current_page == 2 else Color(0.7, 0.75, 0.8, 0.7)
	if btn_page_prev:
		btn_page_prev.disabled = (current_page == 1)
	if btn_page_next:
		btn_page_next.disabled = (current_page == 2)
	refresh_slots()

func refresh_slots() -> void:
	var gs = _get_game_state()
	var base_slot = (current_page - 1) * 6
	
	for i in range(slot_cards.size()):
		var slot_id = base_slot + (i + 1)
		var card = slot_cards[i]
		
		var num_lbl: Label = card.get_node("%SlotNum" + str(i + 1))
		var date_lbl: Label = card.get_node("%SlotDate" + str(i + 1))
		var del_btn: Button = card.get_node("%BtnDelete" + str(i + 1))
		var thumb: TextureRect = card.get_node("%SlotThumb" + str(i + 1))
		var empty_lbl: Label = card.get_node("%EmptyLabel" + str(i + 1))
		var room_lbl: Label = card.get_node("%RoomName" + str(i + 1))
		var stats_lbl: Label = card.get_node("%StatsLine" + str(i + 1))
		var action_hint: Label = card.get_node("%ActionHint" + str(i + 1))
		
		num_lbl.text = "Слот %d" % slot_id
		
		var info: Dictionary = {}
		if gs and gs.has_method("get_slot_info"):
			info = gs.get_slot_info(slot_id)
			
		if not info.get("exists", false):
			# Пустой слот
			date_lbl.text = "—"
			del_btn.visible = false
			thumb.visible = false
			empty_lbl.visible = true
			empty_lbl.text = "ПУСТОЙ СЛОТ"
			room_lbl.text = "Свободный слот"
			stats_lbl.text = "Нет сохранённых данных"
			
			if current_mode == Mode.SAVE:
				action_hint.text = "✚ Сохранить"
				action_hint.modulate = Color(0.4, 0.9, 0.5)
			else:
				action_hint.text = ""
				action_hint.modulate = Color.GRAY
		else:
			# Занятый слот
			date_lbl.text = info.get("timestamp", "")
			del_btn.visible = true
			room_lbl.text = info.get("room_name", "Неизвестная локация")
			
			var hp = info.get("player_health", 100)
			var phase = info.get("day_phase_name", "День")
			var mode_n = info.get("game_mode_name", "Modern")
			stats_lbl.text = "%s • %d HP • %s" % [phase, hp, mode_n]
			
			var img_path = ""
			if gs and gs.has_method("get_slot_image_path"):
				img_path = gs.get_slot_image_path(slot_id)
				
			var img_loaded = false
			if img_path != "" and FileAccess.file_exists(img_path):
				var im = Image.load_from_file(img_path)
				if im:
					thumb.texture = ImageTexture.create_from_image(im)
					thumb.visible = true
					empty_lbl.visible = false
					img_loaded = true
					
			if not img_loaded:
				thumb.visible = false
				empty_lbl.visible = true
				empty_lbl.text = "НЕТ МИНИАТЮРЫ"
				
			if current_mode == Mode.SAVE:
				action_hint.text = "✎ Перезаписать"
				action_hint.modulate = Color(1.0, 0.85, 0.3)
			else:
				action_hint.text = "▶ Загрузить"
				action_hint.modulate = Color(0.4, 0.85, 1.0)

func _get_slot_id_for_card(card_index: int) -> int:
	return (current_page - 1) * 6 + (card_index + 1)

func _on_slot_card_pressed(card_index: int) -> void:
	if confirm_overlay and confirm_overlay.visible:
		return
		
	var slot_id = _get_slot_id_for_card(card_index)
	var gs = _get_game_state()
	var info: Dictionary = {}
	if gs and gs.has_method("get_slot_info"):
		info = gs.get_slot_info(slot_id)
		
	if current_mode == Mode.SAVE:
		if not info.get("exists", false):
			_execute_save_to_slot(slot_id)
		else:
			_ask_confirm("Перезаписать сохранение в Слоте %d?" % slot_id, func(): _execute_save_to_slot(slot_id))
	else:
		if not info.get("exists", false):
			show_toast("Слот %d пуст!", Color(1.0, 0.4, 0.4))
		else:
			if not is_opened_from_title:
				_ask_confirm("Загрузить Слот %d?\nНесохраненный прогресс будет потерян.", func(): _execute_load_from_slot(slot_id))
			else:
				_execute_load_from_slot(slot_id)

func _on_slot_delete_pressed(card_index: int) -> void:
	if confirm_overlay and confirm_overlay.visible:
		return
	var slot_id = _get_slot_id_for_card(card_index)
	_ask_confirm("Удалить сохранение из Слота %d?" % slot_id, func(): _execute_delete_slot(slot_id))

func _execute_save_to_slot(slot_id: int) -> void:
	var gs = _get_game_state()
	if gs and gs.has_method("save_to_slot"):
		var ok = gs.save_to_slot(slot_id, current_screenshot)
		if ok:
			show_toast("✓ Игра успешно сохранена в Слот %d!" % slot_id, Color(0.4, 1.0, 0.5))
			refresh_slots()
		else:
			show_toast("Ошибка при сохранении в Слот %d" % slot_id, Color.RED)

func _execute_load_from_slot(slot_id: int) -> void:
	var gs = _get_game_state()
	if gs and gs.has_method("load_from_slot"):
		var ok = gs.load_from_slot(slot_id)
		if ok:
			visible = false
			game_loaded.emit(slot_id)
		else:
			show_toast("Ошибка при загрузке Слота %d" % slot_id, Color.RED)

func _execute_delete_slot(slot_id: int) -> void:
	var gs = _get_game_state()
	if gs and gs.has_method("delete_slot"):
		gs.delete_slot(slot_id)
		show_toast("Сохранение из Слота %d удалено." % slot_id, Color(1.0, 0.85, 0.3))
		refresh_slots()

func _ask_confirm(prompt_text: String, action: Callable) -> void:
	_ensure_nodes()
	pending_confirm_action = action
	if confirm_prompt:
		confirm_prompt.text = prompt_text
	if confirm_overlay:
		confirm_overlay.visible = true
	if btn_confirm_yes and btn_confirm_yes.is_inside_tree():
		btn_confirm_yes.grab_focus()

func _on_confirm_yes() -> void:
	if confirm_overlay:
		confirm_overlay.visible = false
	if pending_confirm_action.is_valid():
		pending_confirm_action.call()
	pending_confirm_action = Callable()

func _on_confirm_no() -> void:
	confirm_overlay.visible = false
	pending_confirm_action = Callable()

func show_toast(text: String, col: Color = Color.WHITE) -> void:
	if not toast_label:
		return
	toast_label.text = text
	toast_label.modulate = col
	toast_label.modulate.a = 1.0
	
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.0)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if confirm_overlay and confirm_overlay.visible:
				_on_confirm_no()
			else:
				close()
			get_viewport().set_input_as_handled()
