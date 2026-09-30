extends RefCounted

# Attack names use the attacker's viewpoint; guards use the defender's viewpoint.
enum Direction { LEFT, TOP, RIGHT, THRUST }
const NAMES := ["LINKS", "OBEN", "RECHTS", "STICH"]
const ARROWS := ["←", "↑", "→", "↓"]

static func incoming(direction: int) -> int:
	return 2 - direction if direction in [Direction.LEFT, Direction.RIGHT] else direction

static func pose(direction: int, guard := false) -> Vector3:
	if guard:
		return [Vector3(0.1, -0.25, -0.55), Vector3(0.1, 0, -PI / 2), Vector3(0.1, 0.25, 0.55), Vector3(-0.65, 0, -0.9)][direction]
	return [Vector3(-0.4, -0.7, 1.25), Vector3(-0.6, 0, -0.1), Vector3(-0.4, 0.7, -1.25), Vector3(-PI / 2, 0, 0)][direction]
