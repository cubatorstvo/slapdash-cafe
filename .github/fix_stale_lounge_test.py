from pathlib import Path

path = Path('tests/test_cafe_life.gd')
text = path.read_text()
old = '\tcheck(is_equal_approx(float(rested.get("rest",1.0)),1.0),"Visual lounge preview gives neutral next-day rest multiplier")\n'
new = '\tcheck(is_equal_approx(float(rested.get("rest",1.0)),float(p.rest_multiplier)),"Visual lounge preview applies shared next-day rest multiplier")\n'
if old not in text:
    raise SystemExit('stale lounge assertion not found')
path.write_text(text.replace(old, new, 1))
