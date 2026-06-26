# CardEnums.gd — shared enum definitions (ordinals match C# original for scene compatibility)
class_name CardEnums

enum CardRole { CREATURE, RESOURCE, CONTAINER }

enum CardType {
	ANIMAL = 0,
	CROP = 1,
	FISH = 2,
	FECES = 3,
	DEAD_FISH = 4,
	DRY_GRASS = 5,
	PEST = 6,
	FARMLAND = 7,
	DEEP_WATER_FISH_POND = 8,
	RIVER = 9,
	CANAL = 10,
}

enum SolarTerm { NONE, JINGZHE, MANGZHONG, SHUANGJIANG }
