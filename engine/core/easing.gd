class_name Easing
## Port of all GMS2 easing functions

static func linear(t: float, b: float, c: float, d: float) -> float:
	return c * t / d + b

# Quad
static func in_quad(t: float, b: float, c: float, d: float) -> float:
	t /= d
	return c * t * t + b

static func out_quad(t: float, b: float, c: float, d: float) -> float:
	t /= d
	return -c * t * (t - 2) + b

static func inout_quad(t: float, b: float, c: float, d: float) -> float:
	t /= d / 2
	if t < 1:
		return c / 2 * t * t + b
	t -= 1
	return -c / 2 * (t * (t - 2) - 1) + b

# Cubic
static func in_cubic(t: float, b: float, c: float, d: float) -> float:
	t /= d
	return c * t * t * t + b

static func out_cubic(t: float, b: float, c: float, d: float) -> float:
	t = t / d - 1
	return c * (t * t * t + 1) + b

static func inout_cubic(t: float, b: float, c: float, d: float) -> float:
	t /= d / 2
	if t < 1:
		return c / 2 * t * t * t + b
	t -= 2
	return c / 2 * (t * t * t + 2) + b

# Quart
static func in_quart(t: float, b: float, c: float, d: float) -> float:
	t /= d
	return c * t * t * t * t + b

static func out_quart(t: float, b: float, c: float, d: float) -> float:
	t = t / d - 1
	return -c * (t * t * t * t - 1) + b

static func inout_quart(t: float, b: float, c: float, d: float) -> float:
	t /= d / 2
	if t < 1:
		return c / 2 * t * t * t * t + b
	t -= 2
	return -c / 2 * (t * t * t * t - 2) + b

# Quint
static func in_quint(t: float, b: float, c: float, d: float) -> float:
	t /= d
	return c * t * t * t * t * t + b

static func out_quint(t: float, b: float, c: float, d: float) -> float:
	t = t / d - 1
	return c * (t * t * t * t * t + 1) + b

static func inout_quint(t: float, b: float, c: float, d: float) -> float:
	t /= d / 2
	if t < 1:
		return c / 2 * t * t * t * t * t + b
	t -= 2
	return c / 2 * (t * t * t * t * t + 2) + b

# Sine
static func in_sine(t: float, b: float, c: float, d: float) -> float:
	return -c * cos(t / d * (PI / 2)) + c + b

static func out_sine(t: float, b: float, c: float, d: float) -> float:
	return c * sin(t / d * (PI / 2)) + b

static func inout_sine(t: float, b: float, c: float, d: float) -> float:
	return -c / 2 * (cos(PI * t / d) - 1) + b

# Expo
static func in_expo(t: float, b: float, c: float, d: float) -> float:
	if t == 0:
		return b
	return c * pow(2, 10 * (t / d - 1)) + b

static func out_expo(t: float, b: float, c: float, d: float) -> float:
	if t == d:
		return b + c
	return c * (-pow(2, -10 * t / d) + 1) + b

static func inout_expo(t: float, b: float, c: float, d: float) -> float:
	if t == 0:
		return b
	if t == d:
		return b + c
	t /= d / 2
	if t < 1:
		return c / 2 * pow(2, 10 * (t - 1)) + b
	t -= 1
	return c / 2 * (-pow(2, -10 * t) + 2) + b

# Circ
static func in_circ(t: float, b: float, c: float, d: float) -> float:
	t /= d
	return -c * (sqrt(1 - t * t) - 1) + b

static func out_circ(t: float, b: float, c: float, d: float) -> float:
	t = t / d - 1
	return c * sqrt(1 - t * t) + b

static func inout_circ(t: float, b: float, c: float, d: float) -> float:
	t /= d / 2
	if t < 1:
		return -c / 2 * (sqrt(1 - t * t) - 1) + b
	t -= 2
	return c / 2 * (sqrt(1 - t * t) + 1) + b

# Back
static func in_back(t: float, b: float, c: float, d: float) -> float:
	var s := 1.70158
	t /= d
	return c * t * t * ((s + 1) * t - s) + b

static func out_back(t: float, b: float, c: float, d: float) -> float:
	var s := 1.70158
	t = t / d - 1
	return c * (t * t * ((s + 1) * t + s) + 1) + b

static func inout_back(t: float, b: float, c: float, d: float) -> float:
	var s := 1.70158 * 1.525
	t /= d / 2
	if t < 1:
		return c / 2 * (t * t * ((s + 1) * t - s)) + b
	t -= 2
	return c / 2 * (t * t * ((s + 1) * t + s) + 2) + b

# Bounce
static func out_bounce(t: float, b: float, c: float, d: float) -> float:
	t /= d
	if t < (1.0 / 2.75):
		return c * (7.5625 * t * t) + b
	elif t < (2.0 / 2.75):
		t -= 1.5 / 2.75
		return c * (7.5625 * t * t + 0.75) + b
	elif t < (2.5 / 2.75):
		t -= 2.25 / 2.75
		return c * (7.5625 * t * t + 0.9375) + b
	else:
		t -= 2.625 / 2.75
		return c * (7.5625 * t * t + 0.984375) + b

static func in_bounce(t: float, b: float, c: float, d: float) -> float:
	return c - out_bounce(d - t, 0, c, d) + b

static func inout_bounce(t: float, b: float, c: float, d: float) -> float:
	if t < d / 2:
		return in_bounce(t * 2, 0, c, d) * 0.5 + b
	return out_bounce(t * 2 - d, 0, c, d) * 0.5 + c * 0.5 + b

# Elastic
static func in_elastic(t: float, b: float, c: float, d: float) -> float:
	if t == 0 or c == 0:
		return b
	t /= d
	if t == 1:
		return b + c
	var p := d * 0.3
	var s := p / 4.0
	t -= 1
	return -(c * pow(2, 10 * t) * sin((t * d - s) * (2 * PI) / p)) + b

static func out_elastic(t: float, b: float, c: float, d: float) -> float:
	if t == 0 or c == 0:
		return b
	t /= d
	if t == 1:
		return b + c
	var p := d * 0.3
	var s := p / 4.0
	return c * pow(2, -10 * t) * sin((t * d - s) * (2 * PI) / p) + c + b

static func inout_elastic(t: float, b: float, c: float, d: float) -> float:
	if t == 0 or c == 0:
		return b
	t /= d / 2
	if t == 2:
		return b + c
	var p := d * 0.3 * 1.5
	var s := p / 4.0
	if t < 1:
		t -= 1
		return -0.5 * c * pow(2, 10 * t) * sin((t * d - s) * (2 * PI) / p) + b
	t -= 1
	return c * pow(2, -10 * t) * sin((t * d - s) * (2 * PI) / p) * 0.5 + c + b
