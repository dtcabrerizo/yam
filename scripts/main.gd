extends Control
@onready var table: Table = %Table
@onready var board: Board = %Board
@onready var roll_button: Button = %RollButton
@onready var rolls: Array[TextureRect] = [
	%Roll1, %Roll2, %Roll3
]
@onready var foldable_container: FoldableContainer = $FoldableContainer
@onready var roll_button_container: MarginContainer = $MarginContainer2
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport


enum GameState {
	WAITING = 0,
	ROLLING = 1,
	SCORING = 3
}

var state: GameState = GameState.WAITING
var history: Array[Array] = []

func _ready() -> void:
	print("Ready")
	board.connect("roll_finished", _on_roll_finished)
	table.connect("cell_clicked", _on_table_cell_clicked)
	get_tree().root.size_changed.connect(_on_window_resized)
	_on_window_resized()
	
	#var os: String = OS.get_name()
	#if os == "Windows":
		#pass
	#elif os == "Web":
		#var browser_width = JavaScriptBridge.eval("window.innerWidth")
		#print("Browser: ", browser_width)
		#if browser_width > 900:
			#pass
		#else:
			#print("ESCALANDO")
			##foldable_container.scale = Vector2(4.25, 4.25)
			##foldable_container.queue_sort()
			##foldable_container.folded = true
			##roll_button_container.scale = Vector2(4.25, 4.25)
			##roll_button_container.queue_sort()
			#board.camera.move_camera(Vector3(6.0, 9.0, -0.4), 18.0)


func _on_window_resized() -> void:
	var window_size = DisplayServer.window_get_size()
	
	if window_size.y > window_size.x: # --- MODO MOBILE / RETRATO ---
		# 1. O PULO DO GATO: Calculamos a escala baseada na largura da tela.
		# Como sua tabela original tem cerca de 334px de largura, usamos isso como base.
		var largura_base_ui = 334.0
		var escala_dinamica = window_size.x / largura_base_ui
		
		# Limitamos a escala entre 1.0 e 2.5 para evitar distorções extremas
		get_window().content_scale_factor = clamp(escala_dinamica, 1.0, 2.5)
		
		# 2. Configuração do container para ocupar a tela toda
		foldable_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		foldable_container.set_offsets_preset(Control.PRESET_FULL_RECT)
		foldable_container.custom_minimum_size = Vector2.ZERO
		
		table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.size_flags_vertical = Control.SIZE_EXPAND_FILL
		board.camera.move_camera(Vector3(6.0, 9.0, -0.4), 18.0)
		
	else: # --- MODO DESKTOP / PAISAGEM ---
		# No PC, mantemos a escala nativa de 1.0 pois a janela já é larga
		get_window().content_scale_factor = 1.0
		
		foldable_container.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		foldable_container.set_offsets_preset(Control.PRESET_LEFT_WIDE)
		foldable_container.custom_minimum_size = Vector2(326, 504)
		foldable_container.size.x = 334
		
		table.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		table.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		board.camera.reset_view()

	# Mantém o Viewport 3D na resolução nativa do aparelho
	sub_viewport.size = window_size

#func _on_window_resized() -> void:
	#var window_size = DisplayServer.window_get_size()
	#
	## 1. DETECTAR SE ESTÁ NO CELULAR/MODO RETRATO (Tela mais alta que larga)
	#if window_size.y > window_size.x: 
		## --- CONFIGURAÇÃO MOBILE ---
		## Aumentamos o fator de escala da UI para os textos e botões ficarem grandes
		#get_window().content_scale_factor = 1.8
		#
		## Fazemos o FoldableContainer ocupar a tela INTEIRA (Full Rect) quando aberto
		## Isso garante que o usuário consiga clicar perfeitamente nas células
		#foldable_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		#foldable_container.set_offsets_preset(Control.PRESET_FULL_RECT)
		#
		## Zeramos o tamanho mínimo para o Full Rect conseguir controlar o tamanho
		#foldable_container.custom_minimum_size = Vector2.ZERO
#
		#board.camera.move_camera(Vector3(6.0, 9.0, -0.4), 18.0)
		#
	#else:
		## --- CONFIGURAÇÃO DESKTOP / PAISAGEM ---
		## No PC, mantemos a escala padrão em 1.0
		#get_window().content_scale_factor = 1.0
		#
		## Restauramos exatamente os valores originais do seu .tscn
		#foldable_container.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		#foldable_container.set_offsets_preset(Control.PRESET_LEFT_WIDE)
		#foldable_container.custom_minimum_size = Vector2(326, 504)
		#foldable_container.size.x = 334
		#
		#board.camera.reset_view()
		#
#
	## 2. EVITAR QUE O 3D FIQUE EMBAÇADO
	## Quando aumentamos o content_scale_factor, o Godot pode embaçar o 3D.
	## Forçamos o SubViewport a renderizar na resolução nativa em pixels da janela.
	#sub_viewport.size = window_size
			#
	##print("New Size: ", window_size, " <- ", $FoldableContainer.size)
	##print("scale_factor: ", get_window().get_screen_transform().get_scale(), " pizel_size ", get_global_rect().size * get_window().get_screen_transform().get_scale())
	#
	##var real_width = $FoldableContainer.size.x * get_window().get_screen_transform().get_scale()
	##print("Real W: ", real_width)
	#
	#
	
func _on_table_cell_clicked(col: TableCol, cell_id: int) -> void:
	if state == GameState.ROLLING or history.size() == 0: return
	var ret: int = table.set_value(col, cell_id, history)
	if ret >= 0:
		_next_turn()
	
func _update_rolls() -> void:
	for i: int in range(3):
		rolls[i].visible = i < history.size()

func _update_visuals() -> void:
	_update_rolls()
	roll_button.visible = state == GameState.WAITING
	
func _on_roll_finished(dice: Array[int]) -> void:
	print("Roll finished: ", dice)
	history.append(dice)
	state = GameState.WAITING
	table.highlight_candidates(history)
	
	if history.size() == 3:
		state = GameState.SCORING

	_update_visuals()

func _on_roll_button_pressed() -> void:	
	if board.can_roll():
		state = GameState.ROLLING
		_update_visuals()
		board.roll_dice()
	
func _next_turn() -> void:
	state = GameState.WAITING
	history = []
	board.reset_dice()
	table.clear_candidates()
	_update_visuals()
