--!strict
-- Strategic camera tuning. Distances are multiples of the planet's current radius, so framing
-- follows the planet as it grows.
return table.freeze({
	fieldOfView = 50,
	-- Closest view (a few regions fill the screen) and widest view (whole planet with margin).
	minDistance = 1.3,
	maxDistance = 4.4,
	initialZoom = 0.75, -- 0 = closest, 1 = widest, log-space between the two
	wheelStep = 0.08,
	keyZoomPerSecond = 0.6,
	pinchSensitivity = 1.2,
	-- Radians per pixel at the widest zoom; scales down as the camera approaches the surface.
	dragRadiansPerPixel = 0.006,
	keyRadiansPerSecond = 1.6,
	-- Exponential smoothing rates (per second) toward the target zoom / orientation.
	zoomSmoothing = 10,
	rotateSmoothing = 12,
	-- Pointer movement (pixels) below which a press-release counts as a click, not a drag.
	clickSlop = 6,
	-- Client-side fill light so the night side of the map stays readable.
	ambient = Color3.fromRGB(118, 118, 128),
	outdoorAmbient = Color3.fromRGB(150, 150, 160),
})
