extends RefCounted
## 轻 3D 原型场景的建模工具箱。
##
## 全部模型均用 Godot 内置几何体 + 程序化超椭球圆角箱体生成，不依赖外部素材。
## 网格与材质带缓存，3 个工位复用同一份资源，后续扩展到 25 人时也不会重复分配。

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


# ---------- 材质 ----------

static func material(
	color: Color,
	roughness: float = 0.7,
	metallic: float = 0.0,
	emission_color: Color = Color.BLACK,
	emission_strength: float = 0.0
) -> StandardMaterial3D:
	var key := "%s|%.3f|%.3f|%s|%.3f" % [
		color.to_html(true), roughness, metallic, emission_color.to_html(true), emission_strength,
	]
	if _material_cache.has(key):
		return _material_cache[key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	# 程序化圆角箱体的三角形绕序在不同象限可能翻转，关闭背面剔除保证任何角度都完整可见。
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = emission_color
		mat.emission_energy_multiplier = emission_strength
	_material_cache[key] = mat
	return mat


static func glass_material(tint: Color = Color("#dcefff")) -> StandardMaterial3D:
	var key := "glass|%s" % tint.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.08
	mat.metallic = 0.15
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.18
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[key] = mat
	return mat


# ---------- 程序化圆角箱体 ----------

static func rounded_box(size: Vector3, exponent: float = 0.34, rings: int = 12, segments: int = 24) -> ArrayMesh:
	var key := "rbox|%s|%.3f|%d|%d" % [var_to_str(size), exponent, rings, segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := _build_rounded_box(size, exponent, rings, segments)
	_mesh_cache[key] = mesh
	return mesh


static func _build_rounded_box(size: Vector3, exponent: float, rings: int, segments: int) -> ArrayMesh:
	var half := size * 0.5
	var row := segments + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ring in range(rings + 1):
		var v := -PI * 0.5 + PI * float(ring) / float(rings)
		for seg in range(segments + 1):
			var u := TAU * float(seg) / float(segments)
			var p := _super_point(v, u, half, exponent)
			st.set_uv(Vector2(float(seg) / float(segments), float(ring) / float(rings)))
			st.set_normal(_super_normal(v, u, half, exponent, p))
			st.add_vertex(p)

	for ring in range(rings):
		for seg in range(segments):
			var a := ring * row + seg
			var b := a + 1
			var c := a + row
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)

	return st.commit()


static func _super_point(v: float, u: float, half: Vector3, e: float) -> Vector3:
	var cv := cos(v)
	var sv := sin(v)
	var cu := cos(u)
	var su := sin(u)
	return Vector3(
		half.x * _spow(cv, e) * _spow(cu, e),
		half.y * _spow(sv, e),
		half.z * _spow(cv, e) * _spow(su, e)
	)


static func _super_normal(v: float, u: float, half: Vector3, e: float, p: Vector3) -> Vector3:
	var eps := 0.01
	var v2 := clampf(v + eps, -PI * 0.5, PI * 0.5)
	var pv := _super_point(v2, u, half, e)
	var pu := _super_point(v, u + eps, half, e)
	var n := (pv - p).cross(pu - p)
	if n.length_squared() < 0.0000001:
		n = p
		if n.length_squared() < 0.0000001:
			return Vector3.UP
	n = n.normalized()
	if n.dot(p) < 0.0:
		n = -n
	return n


static func _spow(value: float, exponent: float) -> float:
	if value == 0.0:
		return 0.0
	return signf(value) * pow(absf(value), exponent)


# ---------- 基础几何体 ----------

static func sphere(radius: float, radial: int = 24, rings: int = 14) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = radial
	m.rings = rings
	return m


static func hemisphere(radius: float, radial: int = 28, rings: int = 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius
	m.is_hemisphere = true
	m.radial_segments = radial
	m.rings = rings
	return m


static func capsule(radius: float, height: float, radial: int = 16, rings: int = 6) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = radial
	m.rings = rings
	return m


static func cylinder(top_radius: float, bottom_radius: float, height: float, radial: int = 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = radial
	m.rings = 2
	return m


static func torus(inner_radius: float, outer_radius: float, rings: int = 24, ring_segments: int = 10) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = rings
	m.ring_segments = ring_segments
	return m


# ---------- 节点助手 ----------

static func lit(
	parent: Node3D,
	mesh: Mesh,
	pos: Vector3,
	mat: Material,
	rot_degrees: Vector3 = Vector3.ZERO,
	node_name: String = ""
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_degrees
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


## 在两点之间放置一根胶囊，用于四肢、头发、线缆等。
static func segment(
	parent: Node3D,
	from: Vector3,
	to: Vector3,
	radius: float,
	mat: Material,
	node_name: String = ""
) -> MeshInstance3D:
	var dir := to - from
	var length := dir.length()
	var mesh := capsule(radius, maxf(length, radius * 2.0), 14, 4)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = (from + to) * 0.5
	if length > 0.0001:
		mi.quaternion = Quaternion(Vector3.UP, dir.normalized())
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


## 沿折线生成一根平滑圆管，用于贴合曲面的五官线条（闭眼、眼镜框等）。
## 每个截面按切线方向生成圆环，法线直接取径向，避免低面数网格的棱角感。
static func tube(
	parent: Node3D,
	points: Array,
	radius: float,
	mat: Material,
	radial: int = 8,
	node_name: String = ""
) -> MeshInstance3D:
	if points.size() < 2:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array = []
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var tangent: Vector3
		if i == 0:
			tangent = (points[1] - p).normalized()
		elif i == points.size() - 1:
			tangent = (points[i] - points[i - 1]).normalized()
		else:
			tangent = (points[i + 1] - points[i - 1]).normalized()
		var ref := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var axis_x := tangent.cross(ref).normalized()
		var axis_y := axis_x.cross(tangent).normalized()
		var ring: Array = []
		for j in range(radial):
			var a := TAU * float(j) / float(radial)
			ring.append(p + axis_x * cos(a) * radius + axis_y * sin(a) * radius)
		rings.append(ring)

	for i in range(rings.size() - 1):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var c0: Vector3 = points[i]
		for j in range(radial):
			var k := (j + 1) % radial
			_tube_vertex(st, r0[j], c0)
			_tube_vertex(st, r1[j], c0)
			_tube_vertex(st, r1[k], c0)
			_tube_vertex(st, r0[j], c0)
			_tube_vertex(st, r1[k], c0)
			_tube_vertex(st, r0[k], c0)

	# 两端封口
	var n_start: Vector3 = (points[0] - points[1]).normalized()
	var start: Vector3 = points[0]
	for j in range(radial):
		var k := (j + 1) % radial
		st.set_normal(n_start)
		st.add_vertex(start)
		st.set_normal(n_start)
		st.add_vertex(rings[0][k])
		st.set_normal(n_start)
		st.add_vertex(rings[0][j])
	var n_end: Vector3 = (points[points.size() - 1] - points[points.size() - 2]).normalized()
	var end: Vector3 = points[points.size() - 1]
	for j in range(radial):
		var k := (j + 1) % radial
		st.set_normal(n_end)
		st.add_vertex(end)
		st.set_normal(n_end)
		st.add_vertex(rings[rings.size() - 1][j])
		st.set_normal(n_end)
		st.add_vertex(rings[rings.size() - 1][k])

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi


static func _tube_vertex(st: SurfaceTool, vertex: Vector3, center: Vector3) -> void:
	st.set_normal((vertex - center).normalized())
	st.add_vertex(vertex)


## 两点之间的圆锥/尖刺，用于头发、叶片等。
static func cone_between(
	parent: Node3D,
	from: Vector3,
	to: Vector3,
	base_radius: float,
	mat: Material,
	node_name: String = ""
) -> MeshInstance3D:
	var dir := to - from
	var length := dir.length()
	var mesh := cylinder(0.004, base_radius, maxf(length, 0.01), 12)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = (from + to) * 0.5
	if length > 0.0001:
		mi.quaternion = Quaternion(Vector3.UP, dir.normalized())
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	return mi
