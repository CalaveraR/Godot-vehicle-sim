class_name TirePhysicsOrchestrator
extends Node

# ------------------------------------------------------------------------------
# Configurações de orquestração
# ------------------------------------------------------------------------------
@export var solve_rate: float = 120.0                     # Frequência de atualização (Hz)
@export var enable_full_model: bool = true                # Usa modelo completo ou simplificado
@export var use_phys_grid: bool = true                    # Usa grid físico reduzido (performance)

# ------------------------------------------------------------------------------
# Referências para componentes injetados (devem ser atribuídas no editor)
# ------------------------------------------------------------------------------
@export var shader_reader: ShaderContactReader            # Leitor de contatos do shader
@export var raycast_reader: RaycastSampleReader           # Leitor de amostras por raycast
@export var patch_builder: ContactPatchBuilder            # Construtor de patches de contato
@export var authority_policy: InfluenceAuthorityPolicy    # Política de autoridade de influência
@export var contract_builder: InfluenceContractBuilder    # Construtor de contratos de influência
@export var contract_merger: ContractMerger               # Merge de contratos
@export var rate_limiter: ContractRateLimiter             # Limitador de taxa de contratos
@export var applier: ApplyInfluenceToShaderState          # Aplicador de influência no estado do shader
@export var patch_state: ContactPatchState                # Estado dinâmico do patch de contato
@export var contact_fsm: ContactStateMachine              # Máquina de estados do contato
@export var brush_solver: BrushModelSolver                # Solver do modelo de escova (brush)
@export var pressure_solver: PressureFieldSolver          # Solver do campo de pressão
@export var vehicle_body: RigidBody3D                     # Corpo do veículo onde as forças serão aplicadas

# ------------------------------------------------------------------------------
# Variáveis de estado interno
# ------------------------------------------------------------------------------
var _acc_time: float = 0.0                                # Acumulador de tempo para rate limiting
var _camber_angle: float = 0.0                            # Ângulo de cambagem (rad)
var _suspension_load: float = 4000.0                      # Carga vertical da suspensão (N)
var _lateral_accel: float = 0.0                           # Aceleração lateral estimada (m/s²)
var _current_forces: Dictionary = {                       # Últimas forças calculadas
	"Fx": 0.0, "Fy": 0.0, "Fz": 0.0,
	"Mx": 0.0, "My": 0.0, "Mz": 0.0
}
var _last_patch_center: Vector3 = Vector3.ZERO            # Centro de pressão do patch

# ------------------------------------------------------------------------------
# Inicialização
# ------------------------------------------------------------------------------
func _ready() -> void:
	# Inicializa os componentes que necessitam de parâmetros
	if shader_reader and raycast_reader and patch_builder:
		# Exemplo: passa as dimensões do grid para o construtor de patches
		var grid_size = shader_reader.get_grid_size()      # método hipotético
		patch_builder.initialize(grid_size.x, grid_size.y)
	
	if patch_state:
		# Inicializa o estado do patch com as dimensões do grid (físico ou não)
		var grid_w = pressure_solver.phys_grid_w if use_phys_grid and pressure_solver else shader_reader.get_grid_size().x
		var grid_h = pressure_solver.phys_grid_h if use_phys_grid and pressure_solver else shader_reader.get_grid_size().y
		patch_state.initialize(grid_w, grid_h)
	
	if brush_solver:
		var total_cells = patch_state.get_cell_count() if patch_state else 0
		brush_solver.initialize(total_cells)
	
	if contact_fsm:
		contact_fsm.initialize(patch_state)
	
	print("TirePhysicsOrchestrator inicializado. Modo: ", "Físico" if use_phys_grid else "Alta resolução")

# ------------------------------------------------------------------------------
# Loop principal de física
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_acc_time += delta
	
	# Atualiza aceleração lateral (pode vir do veículo ou ser calculada)
	_update_lateral_accel(delta)
	
	# Executa apenas na taxa definida
	if _acc_time >= 1.0 / solve_rate:
		_acc_time = 0.0
		
		if enable_full_model:
			_update_full_model(delta)
		else:
			_update_simple_model(delta)

# ------------------------------------------------------------------------------
# Modelo completo (orquestração completa dos componentes)
# ------------------------------------------------------------------------------
func _update_full_model(delta: float) -> void:
	# 1. Coleta amostras dos leitores
	var shader_samples = shader_reader.get_samples() if shader_reader else []
	var ray_samples = raycast_reader.get_samples() if raycast_reader else []
	var all_samples = shader_samples + ray_samples
	
	if all_samples.is_empty():
		return
	
	# 2. Constrói patches de contato a partir das amostras
	var patches = patch_builder.build_patches(all_samples)
	
	# 3. Determina autoridade de influência (ex: qual fonte tem precedência)
	var authority = authority_policy.determine_authority(patches)
	
	# 4. Constrói contratos de influência
	var contracts = contract_builder.build_contracts(patches, authority, _suspension_load, _camber_angle)
	
	# 5. Merge de contratos (combina múltiplas fontes)
	var merged_contracts = contract_merger.merge(contracts)
	
	# 6. Aplica limitação de taxa (evita atualizações muito frequentes)
	var limited_contracts = rate_limiter.limit(merged_contracts, delta)
	
	# 7. Aplica a influência no estado do shader (se aplicável)
	applier.apply_influence(limited_contracts)
	
	# 8. Atualiza o estado temporal do patch (deflexões, slip, etc.)
	#    Usamos os dados do primeiro patch como referência (simplificação)
	if not patches.is_empty():
		var main_patch = patches[0]
		patch_state.update_states(main_patch, delta)
		
		# 9. Calcula distribuição de pressão (incluindo transferência de carga lateral)
		var pressure_field = pressure_solver.solve_pressure(
			main_patch,
			_suspension_load,
			_camber_angle,
			_lateral_accel
		)
		
		# 10. Aplica o modelo de brush (forças tangenciais)
		var brush_forces = brush_solver.solve_forces(pressure_field, patch_state)
		
		# 11. Integra as forças totais
		_current_forces = brush_solver.integrate_forces(brush_forces)
		
		# 12. Calcula centro de pressão
		_last_patch_center = pressure_solver.calculate_pressure_center(brush_forces)
	
	# 13. Aplica as forças no veículo
	_apply_forces_to_vehicle()

# ------------------------------------------------------------------------------
# Modelo simplificado (fallback rápido)
# ------------------------------------------------------------------------------
func _update_simple_model(delta: float) -> void:
	# Coleta amostras apenas do shader (mais rápido)
	var samples = shader_reader.get_samples() if shader_reader else []
	if samples.is_empty():
		return
	
	# Zera as forças
	_current_forces = {
		"Fx": 0.0, "Fy": 0.0, "Fz": 0.0,
		"Mx": 0.0, "My": 0.0, "Mz": 0.0
	}
	
	# Soma simplificada (apenas para manter o veículo respondendo)
	for sample in samples:
		if sample.penetration > 0:
			_current_forces.Fx += sample.slip_vector.x * 1000.0 * sample.confidence
			_current_forces.Fy += sample.slip_vector.y * 1000.0 * sample.confidence
			_current_forces.Fz += sample.penetration * 1000.0 * sample.confidence
	
	_apply_forces_to_vehicle()

# ------------------------------------------------------------------------------
# Aplicação de forças no corpo do veículo
# ------------------------------------------------------------------------------
func _apply_forces_to_vehicle() -> void:
	if not vehicle_body:
		return
	
	# Aplica força central (resultante)
	vehicle_body.apply_central_force(
		Vector3(_current_forces.Fx, _current_forces.Fz, _current_forces.Fy)
	)
	
	# Aplica torque (se houver)
	if _current_forces.Mx != 0 or _current_forces.My != 0 or _current_forces.Mz != 0:
		vehicle_body.apply_torque(
			Vector3(_current_forces.Mx, _current_forces.Mz, _current_forces.My)
		)
	
	# Aplica força no centro de pressão para efeitos mais realistas
	if use_phys_grid and _last_patch_center != Vector3.ZERO:
		var pressure_force = Vector3(
			_current_forces.Fx * 0.3,
			_current_forces.Fz * 0.3,
			_current_forces.Fy * 0.3
		)
		var application_point = _last_patch_center - vehicle_body.global_position
		vehicle_body.apply_force(pressure_force, application_point)

# ------------------------------------------------------------------------------
# Atualização da aceleração lateral (exemplo simples)
# ------------------------------------------------------------------------------
func _update_lateral_accel(delta: float) -> void:
	if vehicle_body:
		var velocity = vehicle_body.linear_velocity
		var angular_velocity = vehicle_body.angular_velocity
		_lateral_accel = velocity.length() * angular_velocity.y * 0.5

# ------------------------------------------------------------------------------
# Métodos públicos para configuração externa
# ------------------------------------------------------------------------------
func set_camber_angle(angle: float) -> void:
	_camber_angle = angle

func set_suspension_load(load: float) -> void:
	_suspension_load = max(load, 0.0)

func get_current_forces() -> Dictionary:
	return _current_forces.duplicate()

func get_patch_center() -> Vector3:
	return _last_patch_center

# ------------------------------------------------------------------------------
# Métodos de depuração
# ------------------------------------------------------------------------------
func debug_get_statistics() -> Dictionary:
	var stats = {
		"total_force": Vector3(_current_forces.Fx, _current_forces.Fz, _current_forces.Fy).length(),
		"total_torque": Vector3(_current_forces.Mx, _current_forces.Mz, _current_forces.My).length(),
		"patch_center": _last_patch_center,
		"mode": "Phys-grid" if use_phys_grid else "High-res"
	}
	
	if patch_state:
		stats["slipping_cells"] = patch_state.debug_get_slipping_cells()
		stats["avg_deflection"] = patch_state.debug_get_avg_deflection()
	
	if pressure_solver:
		var sample_count = pressure_solver.phys_grid_w * pressure_solver.phys_grid_h if use_phys_grid else shader_reader.get_grid_size().x * shader_reader.get_grid_size().y
		stats["sample_count"] = sample_count
		stats["reduction_factor"] = float(shader_reader.get_grid_size().x * shader_reader.get_grid_size().y) / float(pressure_solver.phys_grid_w * pressure_solver.phys_grid_h) if use_phys_grid else 1.0
	
	return stats

func toggle_phys_grid(enabled: bool) -> void:
	use_phys_grid = enabled
	print("Modo de grid alterado para: ", "Físico" if enabled else "Alta resolução")