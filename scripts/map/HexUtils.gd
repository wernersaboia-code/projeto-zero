extends RefCounted

const HEX_SIZE: float = 40.0

const SQRT3: float = 1.73205080757

const CUBE_DIRECTIONS = [
	Vector3(1, 0, -1), Vector3(1, -1, 0), Vector3(0, -1, 1),
	Vector3(-1, 0, 1), Vector3(-1, 1, 0), Vector3(0, 1, -1)
]

const VERTEX_FLAT_TOP = [
	Vector2(1.0, 0.0),
	Vector2(0.5, SQRT3 / 2.0),
	Vector2(-0.5, SQRT3 / 2.0),
	Vector2(-1.0, 0.0),
	Vector2(-0.5, -SQRT3 / 2.0),
	Vector2(0.5, -SQRT3 / 2.0)
]


static func cube_to_offset(cube: Vector3) -> Vector2i:
	var col = cube.x + (cube.z - int(cube.z < 0)) / 2
	var row = cube.z
	return Vector2i(col, row)


static func offset_to_cube(offset: Vector2i) -> Vector3:
	var q = offset.x - (offset.y - int(offset.y < 0)) / 2
	var r = -q - offset.y
	return Vector3(q, r, offset.y)


static func cube_to_pixel(cube: Vector3, size: float = HEX_SIZE) -> Vector2:
	var x = size * (3.0 / 2.0 * cube.x)
	var y = size * (SQRT3 / 2.0 * cube.x + SQRT3 * cube.z)
	return Vector2(x, y)


static func pixel_to_cube(pixel: Vector2, size: float = HEX_SIZE) -> Vector3:
	var q = (2.0 / 3.0 * pixel.x) / size
	var r = (-1.0 / 3.0 * pixel.x - SQRT3 / 3.0 * pixel.y) / size
	return cube_round(Vector3(q, r, -q - r))


static func cube_round(cube: Vector3) -> Vector3:
	var rq = round(cube.x)
	var rr = round(cube.y)
	var rs = round(cube.z)
	var dq = abs(rq - cube.x)
	var dr = abs(rr - cube.y)
	var ds = abs(rs - cube.z)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector3(rq, rr, -rq - rr)


static func cube_neighbor(cube: Vector3, direction: int) -> Vector3:
	return cube + CUBE_DIRECTIONS[direction]


static func cube_distance(a: Vector3, b: Vector3) -> int:
	return int(max(abs(a.x - b.x), max(abs(a.y - b.y), abs(a.z - b.z))))


static func cube_ring(center: Vector3, radius: int) -> Array[Vector3]:
	if radius < 1:
		return [center]
	var results: Array[Vector3] = []
	var cube = center + CUBE_DIRECTIONS[4] * radius
	for i in range(6):
		for _j in range(radius):
			results.append(cube)
			cube = cube_neighbor(cube, i)
	return results


static func cube_spiral(center: Vector3, radius: int) -> Array[Vector3]:
	var results: Array[Vector3] = [center]
	for k in range(1, radius + 1):
		results.append_array(cube_ring(center, k))
	return results


static func hex_vertices(center: Vector2, size: float = HEX_SIZE) -> PackedVector2Array:
	var verts = PackedVector2Array()
	for v in VERTEX_FLAT_TOP:
		verts.append(center + v * size)
	return verts


static func get_hex_width(size: float = HEX_SIZE) -> float:
	return size * 2.0


static func get_hex_height(size: float = HEX_SIZE) -> float:
	return SQRT3 * size


static func get_horizontal_spacing(size: float = HEX_SIZE) -> float:
	return size * 3.0 / 2.0


static func get_vertical_spacing(size: float = HEX_SIZE) -> float:
	return SQRT3 * size
