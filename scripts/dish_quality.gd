extends RefCounted
## Transparent objective grading. Style is independent of recipe compliance.
const STYLE_MULTIPLIERS := [1.0, 1.2, 1.5, 2.0]
const PRICE_FACTORS := {"D": 0.2, "C": 0.4, "B": 0.6, "A": 0.8, "S": 1.0}

static func style_multiplier(unique_tricks: int) -> float:
	return STYLE_MULTIPLIERS[clampi(unique_tricks, 0, 3)]

static func result(criteria: Array, present: bool, progress: Array) -> Dictionary:
	var score := 0.0
	for criterion in criteria: score += clampf(float(criterion.value), 0, 1)
	score = score / maxf(1, criteria.size()) if present else 0.0
	var grade := "S" if score >= 0.999 else "A" if score >= 0.75 else "B" if score >= 0.5 else "C" if score > 0 else "D"
	return {"criteria": criteria, "present": present, "progress": progress, "score": score, "grade": grade, "style_count": 0, "style_multiplier": 1.0, "price_factor": PRICE_FACTORS[grade] if present else 0.0}

static func with_components(report: Dictionary, components: Array) -> Dictionary:
	report.components = components
	return report

static func missing(report: Dictionary, roles: Array) -> Array:
	var names: Array = []
	for component in report.components:
		if component.role in roles and not component.served: names.append(component.name)
	return names

static func text(report: Dictionary) -> String:
	var lines := PackedStringArray(["РЕЦЕПТ"])
	for component in report.components:
		lines.append(component.name + (" · ✓ на подаче" if component.served else " · ещё не на подаче"))
		for line in component.lines: lines.append(str(line))
		lines.append("")
	lines.append("Качество блюда: " + report.grade)
	if report.get("style_count", 0) > 0:
		lines.append("Эффектная готовка: " + ", ".join(report.get("style_tricks", [])) + " · +20%")
	return "\n".join(lines)
