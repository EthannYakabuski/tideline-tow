extends RefCounted

const DISTRICTS := ["Sunwake Cove", "Copperdock", "Lantern Strait"]
const NAMES := ["First Tow", "Two Little Boats", "The Wide Way", "Rock Garden", "Three's Company", "Outer Buoys", "Around the Island", "Crossing Time", "Cove Collection", "Sunwake Send-off", "Copper Welcome", "Freight Crossing", "Split Channel", "The Long Return", "River Drift", "Busy Water", "Cargo Crescent", "Against the Flow", "Dockside Dance", "Copper Convoy", "First Lantern", "Moonlit Passage", "Twin Currents", "The Quiet Channel", "Night Ferry", "Island Necklace", "Long Blue Line", "Lantern Crossing", "Last Light", "Every Boat Home"]
const TIME_LIMITS := [45,36,42,48,46,55,55,52,62,62,60,60,62,68,64,72,73,70,78,82,72,76,80,82,80,88,92,88,95,100]
const MASTER_PARS := [15,8,10,16,12,17,18,17,21,23,20,19,21,25,19,25,25,21,26,29,21,24,26,26,26,29,31,30,32,37]
# Each entry is hand-authored: rescue positions, rock circles, ferry lanes, current zones.
# Open perimeter routes are deliberately retained around every arrangement.
const LAYOUTS := [
	{"b":[[-5,-5],[0,-9],[5,-5]],"r":[],"f":[],"c":[],"t":45},
	{"b":[[-4,-1],[4,-3]],"r":[],"f":[],"c":[],"t":85},
	{"b":[[-5,-6],[5,-6]],"r":[[0,-2,1.8]],"f":[],"c":[],"t":95},
	{"b":[[-5,-9],[0,-9],[5,-9]],"r":[[-3,-3,1.2],[3,-3,1.2]],"f":[],"c":[],"t":115},
	{"b":[[-5,-3],[0,-6],[5,-3]],"r":[[0,1,1.4]],"f":[],"c":[],"t":110},
	{"b":[[-6,-9],[6,-9],[-5,2],[5,2]],"r":[[-2,-3,1.3],[2,-7,1.3]],"f":[],"c":[],"t":145},
	{"b":[[-5,-7],[0,-10],[5,-7],[5,1]],"r":[[0,-3,2.0]],"f":[],"c":[],"t":145},
	{"b":[[-5,-7],[5,-7],[0,-10]],"r":[],"f":[[0,-2,2.0,6]],"c":[],"t":125},
	{"b":[[-6,-9],[0,-10],[6,-9],[-5,1],[5,1]],"r":[[-3,-4,1.4],[3,-4,1.4]],"f":[],"c":[],"t":175},
	{"b":[[-6,-8],[-2,-10],[3,-10],[6,-5],[5,2]],"r":[[0,-4,1.8]],"f":[[0,2,1.8,6]],"c":[],"t":180},
	{"b":[[-5,-5],[5,-6],[-4,-10],[4,-10]],"r":[[0,-1,1.8]],"f":[],"c":[[0,-7,2.5,0.4,0]],"t":145},
	{"b":[[-6,-8],[0,-9],[6,-8],[5,1]],"r":[[-3,-3,1.2]],"f":[[0,-4,2.2,6]],"c":[],"t":150},
	{"b":[[-6,-7],[-3,-10],[3,-10],[6,-7]],"r":[[0,-6,1.6],[0,1,1.4]],"f":[],"c":[],"t":150},
	{"b":[[-6,-10],[0,-10],[6,-10],[-6,-3],[6,-3]],"r":[[-2,-5,1.5],[3,0,1.6]],"f":[],"c":[[-5,3,2,0,0.6]],"t":180},
	{"b":[[-6,-8],[0,-10],[6,-8],[5,0]],"r":[[0,-3,1.5]],"f":[],"c":[[-4,-3,2,0.9,0],[4,-3,2,-0.9,0]],"t":155},
	{"b":[[-5,-9],[0,-10],[5,-9],[-5,0],[5,0]],"r":[],"f":[[0,-4,2.4,6],[0,3,1.7,5]],"c":[],"t":180},
	{"b":[[-6,-9],[-2,-10],[3,-10],[6,-6],[6,0]],"r":[[-2,-4,1.6],[2,0,1.4]],"f":[[0,-7,1.8,5]],"c":[],"t":185},
	{"b":[[-6,-8],[0,-10],[6,-8],[-5,1],[5,1]],"r":[[0,-4,1.5]],"f":[],"c":[[-5,-3,2.2,0,-1.0],[5,-3,2.2,0,-1.0]],"t":180},
	{"b":[[-6,-9],[0,-10],[6,-9],[-5,-2],[5,-2],[0,2]],"r":[[-3,-6,1.2],[3,-6,1.2]],"f":[[0,0,2.2,6]],"c":[],"t":200},
	{"b":[[-6,-9],[-2,-10],[3,-10],[6,-7],[-5,0],[5,0]],"r":[[0,-5,1.6]],"f":[[0,2,2.4,6]],"c":[[0,-9,2,0.7,0]],"t":205},
	{"b":[[-5,-7],[0,-10],[5,-7],[-5,1],[5,1]],"r":[[0,-3,1.8]],"f":[],"c":[[4,-6,2,0,0.7]],"t":180},
	{"b":[[-6,-9],[0,-10],[6,-9],[-5,-2],[5,-2]],"r":[[-2,-5,1.4],[2,-1,1.4]],"f":[[0,3,2.2,6]],"c":[],"t":185},
	{"b":[[-6,-9],[0,-10],[6,-9],[-6,-2],[6,-2],[0,2]],"r":[[0,-4,1.5]],"f":[],"c":[[-4,-5,2,0.8,0],[4,-5,2,-0.8,0]],"t":200},
	{"b":[[-6,-8],[-2,-10],[3,-10],[6,-6],[-5,1],[5,1]],"r":[[-3,-3,1.3],[3,-3,1.3],[0,-7,1.1]],"f":[],"c":[],"t":205},
	{"b":[[-6,-9],[0,-10],[6,-9],[-5,-1],[5,-1]],"r":[[0,-4,1.4]],"f":[[0,2,2.7,6],[0,-7,2.1,5]],"c":[],"t":195},
	{"b":[[-6,-10],[-2,-10],[3,-10],[6,-7],[-6,0],[6,0]],"r":[[-3,-5,1.1],[2,-5,1.2],[0,1,1.2]],"f":[],"c":[[5,3,2,-0.7,0]],"t":210},
	{"b":[[-6,-8],[-3,-10],[1,-10],[5,-9],[6,-4],[-5,0],[4,1]],"r":[[0,-4,1.8]],"f":[],"c":[],"t":225},
	{"b":[[-6,-9],[-2,-10],[3,-10],[6,-7],[-5,0],[5,0]],"r":[[-3,-4,1.2],[3,-4,1.2]],"f":[[0,3,2.5,6]],"c":[[0,-7,2,0.7,0]],"t":215},
	{"b":[[-6,-9],[-2,-10],[3,-10],[6,-7],[-6,-1],[6,-1],[0,2]],"r":[[0,-5,1.6]],"f":[[0,4,2.4,6],[0,-2,1.8,5]],"c":[],"t":230},
	{"b":[[-6,-10],[-2,-10],[3,-10],[6,-7],[-6,-3],[6,0],[-5,2],[2,2]],"r":[[-2,-5,1.4],[2,-2,1.4]],"f":[[0,5,2.5,6]],"c":[[0,-8,2,0.8,0]],"t":250}
]

static func campaign_count() -> int:
	return LAYOUTS.size()

static func campaign(index: int) -> Dictionary:
	index = clampi(index, 0, LAYOUTS.size() - 1)
	var item: Dictionary = LAYOUTS[index].duplicate(true)
	item["index"] = index
	item["name"] = NAMES[index]
	item["district"] = index / 10
	item["target"] = item.b.size()
	item["time"] = TIME_LIMITS[index]
	item["t"] = TIME_LIMITS[index]
	item["par"] = MASTER_PARS[index]
	return item

static func achievements() -> Array:
	var rows := [
		["first_tow","First Link","Hook your first stranded boat."], ["first_delivery","Safe Harbor","Deliver your first rescue convoy."],
		["convoy_three","Little Fleet","Deliver three boats together."], ["convoy_six","Long Blue Line","Deliver six boats together."],
		["rescue_25","Helping Hands","Bring 25 boats home."], ["rescue_100","Harbor Hero","Bring 100 boats home."], ["rescue_500","Coast Guardian","Bring 500 boats home."],
		["cove_complete","Sunwake Skipper","Finish all 10 Sunwake contracts."], ["dock_complete","Copper Captain","Finish all 10 Copperdock contracts."], ["strait_complete","Lantern Keeper","Finish all 10 Lantern contracts."],
		["campaign_complete","Every Boat Home","Finish all 30 contracts."], ["stars_30","Bright Bearings","Earn 30 campaign stars."], ["stars_90","Perfect Coast","Earn all 90 campaign stars."],
		["clean_contract","Unruffled Waters","Complete a contract without damage."], ["swift_contract","Ahead of the Tide","Finish a contract with half its time left."],
		["endless_1000","Night Watch","Score 1,000 in Endless Watch."], ["daily_watch","Today's Tide","Complete the daily rescue."], ["week_welcome","Seven Sunrises","Claim the seventh consecutive login gift."],
		["level_5","Seasoned Skipper","Reach skipper level 5."], ["level_10","Master Mariner","Reach skipper level 10."]
	]
	var result: Array = []
	for row in rows:
		result.append({"key":row[0],"name":row[1],"description":row[2],"icon":"res://assets/brand/achievements/%s.png" % row[0]})
	return result

static func boards() -> Array:
	return [
		{"key":"total_rescues","name":"Boats Brought Home","description":"Lifetime rescued boats","icon":"res://assets/brand/leaderboards/total_rescues.png"},
		{"key":"best_endless","name":"Endless Watch","description":"Best endless score","icon":"res://assets/brand/leaderboards/best_endless.png"},
		{"key":"skipper_xp","name":"Skipper Experience","description":"Lifetime skipper XP","icon":"res://assets/brand/leaderboards/skipper_xp.png"}
	]

static func quests() -> Array:
	return [{"key":"rescues","name":"Harbor Helpers","description":"Bring 8 boats home","target":8,"coins":45,"xp":25}, {"key":"deliveries","name":"Round Trips","description":"Make 3 harbor deliveries","target":3,"coins":35,"xp":20}, {"key":"score","name":"A Good Watch","description":"Earn 600 rescue points","target":600,"coins":55,"xp":30}]
