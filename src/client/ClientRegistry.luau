--!strict
-- Live client objects, set once by Main. LocalScripts share one module cache, so Studio-only
-- development scripts can observe the real camera and picker without any remote.
return {
	view = nil :: any,
	camera = nil :: any,
	picker = nil :: any,
}
