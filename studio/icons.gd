extends RefCounted
const PATHS={
"Appearance":"<path d='M12 3c0 5-3 8-8 9 5 1 8 4 8 9 1-5 4-8 9-9-5-1-8-4-9-9Z'/><path d='m4 3 .6 1.6L6 5l-1.4.5L4 7l-.5-1.5L2 5l1.5-.4Z'/>",
"Body":"<circle cx='12' cy='4.5' r='2.1'/><path d='m6 13 2.6-5 3.4.8 3.4-.8 2.6 5m-8-2-.8 4.2-1 5.3m5.8-9.5.8 4.2 1 5.3m-4-5.9v6'/>",
"Face":"<path d='M6 10C6 4 9 3 12 3s6 1 6 7v3c0 4-4 8-6 8s-6-4-6-8Z'/><path d='m8.5 10 1.4-.3m4.2 0 1.4.3m-4 4 1-.2m-2 3q1.5.8 3 0'/>",
"Hair":"<path d='M5 18c-2-3-1-6-1-8 0-4 3-7 8-7s8 3 8 7c0 4-2 6-1 9l-4 1m-8-1-3-1m3-4c0-4 3-6 6-8m-2 4c4 1 5 3 5 6'/>",
"Style":"<path d='m8 4-5 3-2 5 4 2 2-3v9h10v-9l2 3 4-2-2-5-5-3c-2 3-6 3-8 0Z'/>",
"Extras":"<path d='m3 9 3-5h12l3 5-9 12Zm0 0h18M9 9l3 12 3-12-3-5Z'/>",
"library":"<path d='M3 6h7l2 2h9v11H3Z'/>",
"save":"<path d='M4 4h13l3 3v13H4Z'/><path d='M8 4v6h8V4M8 20v-6h8v6'/>",
"dice":"<rect x='3.5' y='3.5' width='17' height='17' rx='4' transform='rotate(-9 12 12)'/><circle cx='8' cy='8.5' r='.7'/><circle cx='12' cy='12' r='.7'/><circle cx='16' cy='15.5' r='.7'/>",
"portrait":"<circle cx='12' cy='8' r='3'/><path d='M5 20c0-7 14-7 14 0M3 7V3h4m10 0h4v4'/>",
"full":"<path d='M5 7V3h4m6 0h4v4M5 17v4h4m6 0h4v-4'/><circle cx='12' cy='7' r='1.3'/><path d='M12 10v7m-3-5 3-2 3 2m-3 2-2 4m2-4 2 4'/>",
"rotate":"<path d='M4 12c0 7 16 7 16 0 0-3-5-5-9-5m1-3-4 3 4 3'/>",
"check":"<path d='m5 12 4.5 4.5L19 7'/>",
"edit":"<path d='m5 15 10-10 4 4L9 19l-5 1Zm8-8 4 4'/>",
"star":"<path fill='white' stroke='none' d='M12 0c1.5 8 3.5 10 12 12-8.5 1.8-10.5 4-12 12C10.3 16 8.3 14 0 12 8 10.5 10.4 8 12 0Z'/>",
"undo":"<path d='m8 5-5 5 5 5m-4-5h10a6 6 0 0 1 0 12'/>",
}
static var cache={}
static func get_icon(key:String) -> Texture2D:
	if not cache.has(key):
		var img:=Image.new()
		img.load_svg_from_string("<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='white' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'>"+PATHS[key]+"</svg>",2.)
		cache[key]=ImageTexture.create_from_image(img)
	return cache[key]
