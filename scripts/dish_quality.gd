extends RefCounted
## Transparent objective grading. Style is independent and currently has no detectors.
const STYLE_MULTIPLIERS := [1.0, 1.2, 1.5, 2.0]
const PRICE_FACTORS := {"D": 0.2, "C": 0.4, "B": 0.6, "A": 0.8, "S": 1.0}

static func style_multiplier(unique_tricks: int) -> float:
	return STYLE_MULTIPLIERS[clampi(unique_tricks, 0, 3)]

static func result(criteria: Array, present: bool, progress: Array) -> Dictionary:
	var score := 0.0
	for criterion in criteria: score += clampf(float(criterion.value), 0, 1)
	score = score / maxf(1, criteria.size()) if present else 0.0
	var grade := "S" if score >= 0.999 else "A" if score >= 0.75 else "B" if score >= 0.5 else "C" if score > 0 else "D"
	return {"criteria": criteria, "present": present, "progress": progress, "score": score, "grade": grade, "style_count": 0, "style_multiplier": 1.0, "price_factor": PRICE_FACTORS[grade]}

static func text(report: Dictionary) -> String:
	var lines := PackedStringArray(["РЕЦЕПТ И ПРОГРЕСС"])
	for line in report.progress: lines.append(str(line))
	lines.append("")
	lines.append("НА ПОДАЧЕ" if report.present else "НА ПОДАЧЕ: пока пусто")
	for item in report.criteria: lines.append(str(item.label))
	lines.append("Качество блюда: " + report.grade)
	lines.append("Эффектность: 0/3 · ×1.00")
	lines.append("Трюки появятся позже · бонуса за время нет")
	return "\n".join(lines)
