# res://core/input/raycast/RaycastSampleReader.gd
class_name RaycastSampleReader
extends Node3D

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES EXPORTADAS
# ------------------------------------------------------------------------------
## Número de raios ao longo da largura do pneu.
@export var ray_count: int = 16

## Largura do pneu em metros. Os raios são distribuídos uniformemente nesta largura.
@export var tire_width: float = 0.25

## Altura da origem dos raios em relação à transformação da roda (eixo Y local).
@export var ray_origin_height: float = 0.5

## Comprimento de cada raio, apontando para baixo (direção -Y global).
@export var ray_length: float = 0.35

## Máscara de colisão usada na consulta física.
@export var collision_mask: int = 1

## Confiança base atribuída a cada amostra gerada.
@export var base_confidence: float = 0.8

## Nós a serem excluídos da verificação de colisão (ex.: a própria roda).
@export var exclude_nodes: Array[Node] = []

# ------------------------------------------------------------------------------
# MÉTODO PRINCIPAL – CHAMADO PELO SOLVER
# ------------------------------------------------------------------------------
## Executa a leitura de raios e retorna um array de amostras (TireSample).
##
## @param direct_space_state Estado do espaço físico direto (injetado pelo solver).
## @param now_s            Timestamp atual em segundos.
## @return                 Array[TireSample] contendo as amostras dos contatos.
func read_samples(
    direct_space_state: PhysicsDirectSpaceState3D,
    now_s: float
) -> Array[TireSample]:
    var samples: Array[TireSample] = []

    # A transformação da roda é obtida diretamente da posição global deste nó.
    # Assumimos que o RaycastSampleReader é filho (ou o próprio) da roda.
    var wheel_xform: Transform3D = global_transform
    var inv_basis := wheel_xform.basis.inverse()

    for i in range(ray_count):
        # Coordenada lateral normalizada entre -0.5 e +0.5
        var lat := float(i) / float(max(1, ray_count - 1)) - 0.5

        # Origem do raio no espaço local da roda
        var origin_local := Vector3(lat * tire_width, ray_origin_height, 0.0)
        var origin_ws := wheel_xform * origin_local
        var target_ws := origin_ws + Vector3.DOWN * ray_length

        # Configura a consulta de raio
        var query := PhysicsRayQueryParameters3D.create(origin_ws, target_ws)
        query.exclude = exclude_nodes
        query.collision_mask = collision_mask

        var result := direct_space_state.intersect_ray(query)
        if result:
            var hit_pos_ws: Vector3 = result.position
            var hit_normal_ws: Vector3 = result.normal.normalized()

            # Penetração bruta: quanto do comprimento do raio foi consumido
            var hit_distance := origin_ws.distance_to(hit_pos_ws)
            var penetration := max(0.0, ray_length - hit_distance)

            # Converte ponto e normal para o espaço local da roda (física do solver)
            var hit_pos_local := inv_basis * (hit_pos_ws - wheel_xform.origin)
            var hit_normal_local := (inv_basis * hit_normal_ws).normalized()

            # ID estável: usa o índice do raio (pode ser refinado posteriormente)
            var sample_id := i

            # Cria a amostra usando a fábrica estática da classe TireSample
            var sample := TireSample.from_raycast(
                sample_id,
                hit_pos_local,
                hit_normal_local,
                hit_pos_ws,
                hit_normal_ws,
                penetration,
                base_confidence,
                i,                          # grid_x (índice lateral)
                TireSample.SOURCE_RAYCAST,
                now_s
            )
            samples.append(sample)

    return samples