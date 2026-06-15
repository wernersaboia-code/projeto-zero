static func generate_elevation_grid(width: int, height: int) -> Array:
	var grid = []
	grid.resize(width * height)

	var noise = FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = 0.05
	noise.fractal_octaves = 2
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	for col in width:
		for row in height:
			var nx = float(col) / float(width)
			var ny = float(row) / float(height)

			var continent_score = 0.0
			for c in _CONTINENTS:
				var dx = (nx - c.x) / c.z
				var dy = (ny - c.y) / c.w
				var d2 = dx*dx + dy*dy
				if d2 < 1.0:
					var val = (1.0 - d2)
					continent_score += val * val * 0.8

			if ny > 0.86:
				var ant_frac = (ny - 0.86) / 0.14
				continent_score += ant_frac * ant_frac * 0.6

			var noise_val = noise.get_noise_2d(nx * 4.0, ny * 4.0) * 0.06
			var elevation = clamp(continent_score + noise_val, 0.0, 1.0)

			grid[col + row * width] = elevation

	return grid


# Continents on equirectangular 80x50 grid: (nx, ny, rx, ry)
# nx = (long+180)/360, ny = (90-lat)/180
const _CONTINENTS: Array = [
	# North America (long ~-130 to -55, lat 25-55)
	Vector4(0.22, 0.25, 0.10, 0.08),
	# South America (long ~-80 to -35, lat -55-10)
	Vector4(0.34, 0.58, 0.06, 0.18),
	# Europe (long ~-10 to 40, lat 35-60)
	Vector4(0.53, 0.22, 0.07, 0.07),
	# Scandinavia (long 5-30, lat 55-70)
	Vector4(0.53, 0.15, 0.04, 0.05),
	# British Isles
	Vector4(0.48, 0.21, 0.02, 0.03),
	# Africa (long ~-20 to 52, lat -35-37)
	Vector4(0.54, 0.49, 0.10, 0.20),
	# Madagascar
	Vector4(0.62, 0.66, 0.02, 0.04),
	# Asia (long 25-140, lat 5-75)
	Vector4(0.73, 0.28, 0.16, 0.19),
	# India (long 68-88, lat 8-37)
	Vector4(0.72, 0.37, 0.03, 0.08),
	# SE Asia (long 95-110, lat 5-28)
	Vector4(0.77, 0.35, 0.03, 0.07),
	# Japan (long 130-145, lat 30-45)
	Vector4(0.86, 0.31, 0.02, 0.04),
	# Indonesia + Philippines (long 95-145, lat -10-20)
	Vector4(0.80, 0.47, 0.06, 0.05),
	# Australia (long 110-155, lat -40 to -10)
	Vector4(0.87, 0.64, 0.06, 0.08),
	# New Zealand
	Vector4(0.93, 0.74, 0.015, 0.03),
	# Greenland (long -55 to -20, lat 60-82)
	Vector4(0.39, 0.10, 0.05, 0.06),
	# Middle East / Arabia (long 35-55, lat 12-32)
	Vector4(0.61, 0.36, 0.03, 0.06),
	# Caribbean
	Vector4(0.32, 0.43, 0.03, 0.02),
	# Central America (isthmus)
	Vector4(0.31, 0.40, 0.02, 0.04),
]
