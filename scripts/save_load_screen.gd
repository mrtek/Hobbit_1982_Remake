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
	_ensure_nodes()
	if slot_cards.size() > 0 and slot_cards[0].has_node("%BtnCardAction1"):
		var btn = slot_cards[0].get_node("%BtnCardAction1")
		if btn.is_inside_tree():
			btn.grab_focus()
	elif btn_close and btn_close.is_inside_tree():
		btn_close.grab_focus()
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	_speak_accessibility("Save Game screen. Slots 1 to 6 available. Use arrow keys or number keys 1-6. Press Escape to close." if is_en else "Экран сохранения игры. Доступны слоты с 1 по 6. Используйте стрелки для выбора или цифровые клавиши от 1 до 6 на клавиатуре. Клавиша Escape для закрытия.")

func open_load(from_title: bool = false) -> void:
	is_opened_from_title = from_title
	set_mode(Mode.LOAD)
	visible = true
	_ensure_nodes()
	if slot_cards.size() > 0 and slot_cards[0].has_node("%BtnCardAction1"):
		var btn = slot_cards[0].get_node("%BtnCardAction1")
		if btn.is_inside_tree():
			btn.grab_focus()
	elif btn_close and btn_close.is_inside_tree():
		btn_close.grab_focus()
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	_speak_accessibility("Load Game screen. Slots 1 to 6 available. Use arrow keys or number keys 1-6. Press Escape to close." if is_en else "Экран загрузки игры. Доступны слоты с 1 по 6. Используйте стрелки для выбора или цифровые клавиши от 1 до 6 на клавиатуре. Клавиша Escape для закрытия.")

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
	
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	if btn_tab_save:
		btn_tab_save.text = "SAVE" if is_en else "СОХРАНИТЬ"
	if btn_tab_load:
		btn_tab_load.text = "LOAD" if is_en else "ЗАГРУЗИТЬ"
	if btn_close:
		btn_close.text = "✕ CLOSE" if is_en else "✕ ЗАКРЫТЬ"
	if btn_back_bottom:
		btn_back_bottom.text = "← BACK TO GAME" if is_en else "← НАЗАД В ИГРУ"
	if btn_confirm_yes:
		btn_confirm_yes.text = "YES" if is_en else "ДА"
	if btn_confirm_no:
		btn_confirm_no.text = "CANCEL" if is_en else "ОТМЕНА"

	if current_mode == Mode.SAVE:
		if title_label:
			title_label.text = "SAVE GAME" if is_en else "СОХРАНЕНИЕ ИГРЫ"
		if btn_tab_save:
			btn_tab_save.modulate = Color.WHITE
			btn_tab_save.add_theme_color_override("font_color", gold_col)
		if btn_tab_load:
			btn_tab_load.modulate = Color(0.8, 0.8, 0.8, 0.7)
			btn_tab_load.add_theme_color_override("font_color", dim_col)
	else:
		if title_label:
			title_label.text = "LOAD GAME" if is_en else "ЗАГРУЗКА ИГРЫ"
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
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	if btn_page_prev:
		btn_page_prev.disabled = (current_page == 1)
		btn_page_prev.text = "← PREV" if is_en else "← НАЗАД"
	if btn_page_next:
		btn_page_next.disabled = (current_page == 2)
		btn_page_next.text = "NEXT →" if is_en else "ВПЕРЕД →"
	if btn_page_1:
		btn_page_1.text = "SLOTS 1-6" if is_en else "СЛОТЫ 1-6"
	if btn_page_2:
		btn_page_2.text = "SLOTS 7-12" if is_en else "СЛОТЫ 7-12"
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
		
		var is_en = (gs and gs.has_method("is_english") and gs.is_english())
		num_lbl.text = ("Slot %d" if is_en else "Слот %d") % slot_id
		
		var info: Dictionary = {}
		if gs and gs.has_method("get_slot_info"):
			info = gs.get_slot_info(slot_id)
			
		if not info.get("exists", false):
			# Пустой слот
			date_lbl.text = "—"
			del_btn.visible = false
			thumb.visible = false
			empty_lbl.visible = true
			empty_lbl.text = "EMPTY SLOT" if is_en else "ПУСТОЙ СЛОТ"
			room_lbl.text = "Empty Slot" if is_en else "Свободный слот"
			stats_lbl.text = "No saved data" if is_en else "Нет сохранённых данных"
			
			if current_mode == Mode.SAVE:
				action_hint.text = "+ Save" if is_en else "+ Сохранить"
				action_hint.modulate = Color(0.4, 0.9, 0.5)
			else:
				action_hint.text = ""
				action_hint.modulate = Color.GRAY
		else:
			# Занятый слот
			date_lbl.text = info.get("timestamp", "")
			del_btn.visible = true
			del_btn.tooltip_text = "Delete save" if is_en else "Удалить сохранение"
			room_lbl.text = info.get("room_name", "Unknown Location" if is_en else "Неизвестная локация")
			
			var hp = info.get("player_health", 100)
			var phase = info.get("day_phase_name", "Day" if is_en else "День")
			var mode_n = info.get("game_mode_name", "Modern")
			stats_lbl.text = "%s | %d HP | %s" % [phase, hp, mode_n]
			
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
				empty_lbl.text = "NO THUMBNAIL" if is_en else "НЕТ МИНИАТЮРЫ"
				
			if current_mode == Mode.SAVE:
				action_hint.text = "Overwrite" if is_en else "Перезаписать"
				action_hint.modulate = Color(1.0, 0.85, 0.3)
			else:
				action_hint.text = "Load" if is_en else "Загрузить"
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
		
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	if current_mode == Mode.SAVE:
		if not info.get("exists", false):
			_execute_save_to_slot(slot_id)
		else:
			var prompt = ("Overwrite save in Slot %d?" if is_en else "Перезаписать сохранение в Слоте %d?") % slot_id
			_ask_confirm(prompt, func(): _execute_save_to_slot(slot_id))
	else:
		if not info.get("exists", false):
			var toast = ("Slot %d is empty!" if is_en else "Слот %d пуст!") % slot_id
			show_toast(toast, Color(1.0, 0.4, 0.4))
		else:
			if not is_opened_from_title:
				var prompt = ("Load Slot %d?\nUnsaved progress will be lost." if is_en else "Загрузить Слот %d?\nНесохраненный прогресс будет потерян.") % slot_id
				_ask_confirm(prompt, func(): _execute_load_from_slot(slot_id))
			else:
				_execute_load_from_slot(slot_id)

func _on_slot_delete_pressed(card_index: int) -> void:
	if confirm_overlay and confirm_overlay.visible:
		return
	var slot_id = _get_slot_id_for_card(card_index)
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	var prompt = ("Delete save from Slot %d?" if is_en else "Удалить сохранение из Слота %d?") % slot_id
	_ask_confirm(prompt, func(): _execute_delete_slot(slot_id))

func _execute_save_to_slot(slot_id: int) -> void:
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	if gs and gs.has_method("save_to_slot"):
		var ok = gs.save_to_slot(slot_id, current_screenshot)
		if ok:
			var msg = ("Game successfully saved to Slot %d!" if is_en else "Игра успешно сохранена в Слот %d!") % slot_id
			show_toast(msg, Color(0.4, 1.0, 0.5))
			refresh_slots()
		else:
			var msg = ("Error saving to Slot %d" if is_en else "Ошибка при сохранении в Слот %d") % slot_id
			show_toast(msg, Color.RED)

func _execute_load_from_slot(slot_id: int) -> void:
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	if gs and gs.has_method("load_from_slot"):
		var ok = gs.load_from_slot(slot_id)
		if ok:
			visible = false
			game_loaded.emit(slot_id)
		else:
			var msg = ("Error loading Slot %d" if is_en else "Ошибка при загрузке Слота %d") % slot_id
			show_toast(msg, Color.RED)

func _execute_delete_slot(slot_id: int) -> void:
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	if gs and gs.has_method("delete_slot"):
		gs.delete_slot(slot_id)
		var msg = ("Save from Slot %d deleted." if is_en else "Сохранение из Слота %d удалено.") % slot_id
		show_toast(msg, Color(1.0, 0.85, 0.3))
		refresh_slots()

func _ask_confirm(prompt_text: String, action: Callable) -> void:
	_ensure_nodes()
	pending_confirm_action = action
	var gs = _get_game_state()
	var is_en = (gs and gs.has_method("is_english") and gs.is_english())
	var header_lbl = confirm_overlay.get_node_or_null("Card/Margin/VBox/Header") if confirm_overlay else null
	if header_lbl:
		header_lbl.text = "CONFIRMATION" if is_en else "ПОДТВЕРЖДЕНИЕ"
	if confirm_prompt:
		confirm_prompt.text = prompt_text
	if confirm_overlay:
		confirm_overlay.visible = true
	if btn_confirm_yes and btn_confirm_yes.is_inside_tree():
		btn_confirm_yes.grab_focus()
	var suffix = " Yes or Cancel button." if is_en else " Кнопка Да или Отмена."
	_speak_accessibility(prompt_text.replace("\n", " ") + suffix)

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
	_speak_accessibility(text)

func _speak_accessibility(text: String) -> void:
	var gs = _get_game_state()
	if gs and gs.is_accessibility_mode and main_ref and main_ref.has_method("_speak_text"):
		main_ref._speak_text(text, true)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if confirm_overlay and confirm_overlay.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				_on_confirm_no()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var idx = event.keycode - KEY_1
			_on_slot_card_pressed(idx)
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_6:
			var idx = event.keycode - KEY_KP_1
			_on_slot_card_pressed(idx)
			get_viewport().set_input_as_handled()
